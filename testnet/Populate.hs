{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Populate (
    createPopulateConfig,
    testScriptTrigger,
    escrow,
    runFanout,
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Misc
import Control.Monad (void)
import Data.Function ((&))
import Data.Maybe (fromJust)
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream qualified as Stream
import Streamly.Unicode.String (str)
import System.FilePath ((</>))

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

alwaysTruePolicyV2 :: String
alwaysTruePolicyV2 = [str|
{
    "type": "PlutusScriptV2",
    "description": "",
    "cborHex": "46010000224981"
}
|]

alwaysTrueValidatorV2 :: String
alwaysTrueValidatorV2 = [str|
{
    "type": "PlutusScriptV2",
    "description": "",
    "cborHex": "46010000222499"
}
|]

alwaysTrueV3 :: String
alwaysTrueV3 = [str|
{
    "type": "PlutusScriptV3",
    "description": "",
    "cborHex": "450101002499"
}
|]

createTracingConfig ::
    String ->
    String ->
    String ->
    IO ()
createTracingConfig policyTxt validatorTxt scriptsDirName = do
    let scriptsDirPath = env_LOCAL_CONFIG_DIR </> scriptsDirName

    runCmd_ [str|mkdir -p #{scriptsDirPath}|]
    writeFile (scriptsDirPath </> "policy.plutus") policyTxt
    writeFile (scriptsDirPath </> "validator.plutus") validatorTxt

    buildStakeAddress
        [ opt "stake-script-file" (scriptsDirPath </> "policy.plutus")
        , opt "out-file" (scriptsDirPath </> "script.stake.addr")
        ]
    -- 400_000 here comes from:
    -- cardano-cli conway query protocol-parameters
    --    \ --testnet-magic 42
    --    \ --socket-path "devnet-env/socket/node1/sock"
    --    \ | jq .stakeAddressDeposit
    genRegCertStakeAddress
        [ opt "stake-script-file" (scriptsDirPath </> "policy.plutus")
        , opt "out-file" (scriptsDirPath </> "registration.cert")
        , opt "key-reg-deposit-amt" (400_000 :: Int)
        ]
    genDeregCertStakeAddress
        [ opt "stake-script-file" (scriptsDirPath </> "policy.plutus")
        , opt "out-file" (scriptsDirPath </> "deregistration.cert")
        , opt "key-reg-deposit-amt" (400_000 :: Int)
        ]

createPopulateConfig :: IO ()
createPopulateConfig = do
    runCmd_ [str|mkdir -p #{env_LOCAL_CONFIG_DIR}|]
    createTracingConfig alwaysTrueV3 alwaysTrueV3 "tracing-plutus-v3"
    createTracingConfig alwaysTruePolicyV2 alwaysTrueValidatorV2 "tracing-plutus-v2"

--------------------------------------------------------------------------------
-- Test script trigger
--------------------------------------------------------------------------------

data AppEnv = AppEnv
    { validatorAddress :: String
    , assetClass :: String
    , faucetAddr :: String
    , policyFilePath :: FilePath
    , validatorFilePath :: FilePath
    , stakeAddrFilePath :: FilePath
    , regCertFilePath :: FilePath
    , deregCertFilePath :: FilePath
    , numIterations :: Int
    , assetAmount :: String
    }

makeAppEnv :: String -> IO AppEnv
makeAppEnv scriptsDirName = do
    let scriptsDirPath = env_LOCAL_CONFIG_DIR </> scriptsDirName
        policyFilePath = scriptsDirPath </> "policy.plutus"
        validatorFilePath = scriptsDirPath </> "validator.plutus"
        stakeAddrFilePath = scriptsDirPath </> "script.stake.addr"
        regCertFilePath = scriptsDirPath </> "registration.cert"
        deregCertFilePath = scriptsDirPath </> "deregistration.cert"
        tokenName = "TEST_TOKEN"
        assetAmount = "100"
        numIterations = 10

    policyId <- getPolicyId policyFilePath
    faucetAddr <- env_FAUCET_WALLET_ADDR
    tokenNameHex <- hexify tokenName
    validatorAddress <- getScriptAddress validatorFilePath
    let assetClass = [str|#{policyId}.#{tokenNameHex}|]

    printVar "faucetAddr" faucetAddr
    printVar "validatorAddress" validatorAddress

    pure $
        AppEnv
            { validatorAddress = validatorAddress
            , assetClass = assetClass
            , faucetAddr = faucetAddr
            , policyFilePath = policyFilePath
            , validatorFilePath = validatorFilePath
            , assetAmount = assetAmount
            , numIterations = numIterations
            , stakeAddrFilePath = stakeAddrFilePath
            , regCertFilePath = regCertFilePath
            , deregCertFilePath = deregCertFilePath
            }

finalizeCurrentTransaction :: IO ()
finalizeCurrentTransaction = do
    signTransaction
        [ opt "signing-key-file" env_FAUCET_WALLET_SKEY_FILE
        , opt "tx-body-file" env_TX_UNSIGNED
        , opt "out-file" env_TX_SIGNED
        ]
    submitTransaction
        [ opt "tx-file" env_TX_SIGNED
        ]

runMint :: AppEnv -> IO String
runMint AppEnv{..} = do
    ensureBlankWorkDir
    faucetUtxo <- getFirstUtxoAt faucetAddr
    printStep "Mint"
    buildTransaction
        [ opt "tx-in" faucetUtxo
        , opt "tx-in-collateral" faucetUtxo
        , opt "tx-out" [str|#{validatorAddress} + 2000000 + #{assetAmount} #{assetClass}|]
        , opt "tx-out-inline-datum-value" (10 :: Int)
        , opt "mint" [str|#{assetAmount} #{assetClass}|]
        , opt "mint-script-file" policyFilePath
        , opt "mint-redeemer-value" (5 :: Int)
        , opt "change-address" faucetAddr
        , opt "out-file" env_TX_UNSIGNED
        ]
    finalizeCurrentTransaction
    mintTx <- getTransactionId env_TX_SIGNED
    printVar "mintTx" mintTx
    waitTillExists $ fstOutput mintTx
    pure mintTx

runSpend :: AppEnv -> String -> IO String
runSpend AppEnv{..} lockedUtxo = do
    ensureBlankWorkDir

    faucetUtxo <- getFirstUtxoAt faucetAddr
    printVar "faucetUtxo" faucetUtxo

    printStep "Spend"
    buildTransaction
        [ opt "tx-in" faucetUtxo
        , opt "tx-in" lockedUtxo
        , opt "tx-in-script-file" validatorFilePath
        , flg "tx-in-inline-datum-present"
        , opt "tx-in-redeemer-value" (10 :: Int)
        , opt "tx-in-collateral" faucetUtxo
        , opt "tx-out" [str|#{validatorAddress} + 2000000 + #{assetAmount} #{assetClass}|]
        , opt "tx-out-inline-datum-value" (20 :: Int)
        , opt "change-address" faucetAddr
        , opt "out-file" env_TX_UNSIGNED
        ]
    finalizeCurrentTransaction
    spendTx <- getTransactionId env_TX_SIGNED
    printVar "spendTx" spendTx
    waitTillExists $ fstOutput spendTx
    pure spendTx

runBurn :: AppEnv -> String -> IO ()
runBurn AppEnv{..} lockedUtxo = do
    ensureBlankWorkDir

    faucetUtxo <- getFirstUtxoAt faucetAddr
    printVar "faucetUtxo" faucetUtxo

    printStep "Burn"
    buildTransaction
        [ opt "tx-in" faucetUtxo
        , opt "tx-in" lockedUtxo
        , opt "tx-in-script-file" validatorFilePath
        , flg "tx-in-inline-datum-present"
        , opt "tx-in-redeemer-value" (10 :: Int)
        , opt "tx-in-collateral" faucetUtxo
        , opt "mint" [str|-#{assetAmount} #{assetClass}|]
        , opt "mint-script-file" policyFilePath
        , opt "mint-redeemer-value" (5 :: Int)
        , opt "change-address" faucetAddr
        , opt "out-file" env_TX_UNSIGNED
        ]
    finalizeCurrentTransaction
    burnTx <- getTransactionId env_TX_SIGNED
    waitTillExists $ fstOutput burnTx
    printVar "burnTx" burnTx

runCertifyReg :: AppEnv -> IO ()
runCertifyReg AppEnv{..} = do
    printStep "Certify - Reg"

    faucetUtxo <- getFirstUtxoAt faucetAddr
    buildTransaction
        [ opt "tx-in" faucetUtxo
        , opt "tx-in-collateral" faucetUtxo
        , opt "change-address" faucetAddr
        , opt "certificate-file" regCertFilePath
        , opt "certificate-script-file" policyFilePath
        , opt "certificate-redeemer-value" (7 :: Int)
        , opt "out-file" env_TX_UNSIGNED
        ]
    finalizeCurrentTransaction
    txId <- getTransactionId env_TX_SIGNED
    waitTillExists $ fstOutput txId
    printVar "runCertifyReg.txId" txId

runCertifyDereg :: AppEnv -> IO ()
runCertifyDereg AppEnv{..} = do
    printStep "Certify - Dereg"

    faucetUtxo <- getFirstUtxoAt faucetAddr
    buildTransaction
        [ opt "tx-in" faucetUtxo
        , opt "tx-in-collateral" faucetUtxo
        , opt "change-address" faucetAddr
        , opt "certificate-file" deregCertFilePath
        , opt "certificate-script-file" policyFilePath
        , opt "certificate-redeemer-value" (7 :: Int)
        , opt "out-file" env_TX_UNSIGNED
        ]
    finalizeCurrentTransaction
    txId <- getTransactionId env_TX_SIGNED
    waitTillExists $ fstOutput txId
    printVar "runCertifyDereg.txId" txId

runReward :: AppEnv -> IO ()
runReward AppEnv{..} = do
    printStep "Reward"

    faucetUtxo <- getFirstUtxoAt faucetAddr
    stakeAddr <- readFile stakeAddrFilePath
    buildTransaction
        [ opt "tx-in" faucetUtxo
        , opt "tx-in-collateral" faucetUtxo
        , opt "change-address" faucetAddr
        , -- NOTE: +0 is a handy way to trigger the script without involving any
          -- funds.
          opt "withdrawal" [str|#{stakeAddr}+0|]
        , opt "withdrawal-script-file" policyFilePath
        , opt "withdrawal-redeemer-value" (9 :: Int)
        , opt "out-file" env_TX_UNSIGNED
        ]
    finalizeCurrentTransaction
    txId <- getTransactionId env_TX_SIGNED
    waitTillExists $ fstOutput txId
    printVar "runReward.txId" txId

testScriptTriggerWith :: AppEnv -> IO ()
testScriptTriggerWith appEnv = do
    utxo0 <- fstOutput <$> runMint appEnv
    utxo1 <- fstOutput <$> runSpend appEnv utxo0
    runBurn appEnv utxo1
    runCertifyReg appEnv
    runReward appEnv
    runCertifyDereg appEnv

testScriptTrigger :: IO ()
testScriptTrigger = do
    testScriptTriggerWith =<< makeAppEnv "tracing-plutus-v2"
    testScriptTriggerWith =<< makeAppEnv "tracing-plutus-v3"

--------------------------------------------------------------------------------
-- Fanout
--------------------------------------------------------------------------------

data FanoutConfig = FanoutConfig
    { fcValidatorAddr :: String
    , fcValidatorFilePath :: String
    , fcFaucetAddr :: String
    }

makeFanoutConfig :: FilePath -> IO FanoutConfig
makeFanoutConfig alwaysTrueScriptPath = do
    let fcValidatorFilePath = alwaysTrueScriptPath
    fcFaucetAddr <- env_FAUCET_WALLET_ADDR
    fcValidatorAddr <- getScriptAddress fcValidatorFilePath

    printVar "fcFaucetAddr" fcFaucetAddr
    printVar "fcValidatorAddr" fcValidatorAddr

    pure $
        FanoutConfig
            { fcValidatorAddr
            , fcValidatorFilePath
            , fcFaucetAddr
            }

type UtxoRef = String

fanout :: FanoutConfig -> Int -> [UtxoRef] -> IO [UtxoRef]
fanout FanoutConfig{..} spread inpUtxos = do
    ensureBlankWorkDir

    faucetUtxo <- getFirstUtxoAt fcFaucetAddr
    printVar "faucetUtxo" faucetUtxo

    let optTxInAdditional =
            [ opt "tx-in-script-file" fcValidatorFilePath
            , opt "tx-in-redeemer-value" (10 :: Int)
            , opt "tx-in-collateral" faucetUtxo
            ]

        txInList = (: optTxInAdditional) . opt "tx-in" <$> inpUtxos
        txOutList =
            opt "tx-out"
                <$> replicate spread [str|#{fcValidatorAddr} + 1000000|]

    printStep "fanout"
    buildTransaction $
        concat
            [
                [ opt "tx-in" faucetUtxo
                , opt "change-address" fcFaucetAddr
                , opt "out-file" env_TX_UNSIGNED
                ]
            , concat txInList
            , txOutList
            ]
    finalizeCurrentTransaction
    txId <- getTransactionId env_TX_SIGNED
    printVar "txId" txId
    waitTillExists $ fstOutput txId
    let mkUtxoRef i = txId ++ "#" ++ show i
    pure $ map mkUtxoRef [0 .. (spread - 1)]

runFanout :: IO ()
runFanout = do
    let alwaysTrueScriptPath =
            env_LOCAL_CONFIG_DIR </> "tracing-plutus-v3/validator.plutus"
    fc <- makeFanoutConfig alwaysTrueScriptPath
    (nextSpread, utxos) <-
        Stream.iterateM (iterFunc fc (+ 1)) (pure (1, []))
            & Stream.take 10
            & Stream.fold Fold.latest
            & fmap fromJust
    Stream.iterateM (iterFunc fc (\x -> x - 1)) (pure (nextSpread - 1, utxos))
        & Stream.take 10
        & Stream.fold Fold.drain
  where
    iterFunc fc incF (spread, inp) = do
        outs <- fanout fc spread inp
        pure (incF spread, outs)

--------------------------------------------------------------------------------
-- Escrow
--------------------------------------------------------------------------------

-- TODO: Add escrow logic
escrow :: IO ()
escrow = do
    alice <- fetchWallet env_LOCAL_CONFIG_DIR "alice"
    bob <- fetchWallet env_LOCAL_CONFIG_DIR "bob"
    faucet <- env_FAUCET_WALLET
    void $ transferAda faucet alice 2000000
    void $ transferAda faucet bob 2000000
