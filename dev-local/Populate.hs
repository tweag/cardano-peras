{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Populate (
    -- Utils
    printStep,
    runCmd_,
    runCmd,
    flg,
    opt,
    raw,
    drain,
    getPolicyId,
    Wallet (..),
    mkWallet,
    walletKeyHash,
    buildStakeAddress,
    genRegCertStakeAddress,
    genDeregCertStakeAddress,
    firstNonEmptyLine,
    optNode1Socket,
    replaceAllNeighboursWithProxy,
    toxiproxyServer,
    toxiproxyCreateClients,
    saveMappings,
    getNodeTips,
    addToxicity,
    removeToxicity,
    -- Globals
    env_LOCAL_CONFIG_DIR,
    env_PLUTUS_SCRIPTS_DIR,
    env_POPULATE_WORK_DIR,
    env_TESTNET_WORK_DIR,
    env_CARDANO_TESTNET_MAGIC,
    env_CARDANO_TESTNET_NUM_NODES,
    -- Main
    testScriptTrigger,
    escrow,
    runFanout,
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Streamly.Console.Stdio qualified as Stdio
import Control.Concurrent (threadDelay)
import Control.Monad (void)
import Data.Function ((&))
import Data.List ((\\))
import Data.Maybe (fromJust)
import Data.Word (Word8)
import Streamly.Data.Array (Array)
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream (Stream)
import Streamly.Data.Stream qualified as Stream
import Streamly.FileSystem.FileIO qualified as File
import Streamly.FileSystem.Path qualified as Path
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.Stream qualified as Unicode
import Streamly.Unicode.String (str)
import System.FilePath ((<.>), (</>))
import Data.Map qualified as Map
import Data.IntMap qualified as IntMap
import Data.Map (Map)
import Data.IntMap (IntMap)

-------------------------------------------------------------------------------
-- Utils
-------------------------------------------------------------------------------

divider :: String
divider = replicate 80 '-'

printStep :: String -> IO ()
printStep s = putStrLn . unlines $ ["", divider, s, divider]

drain :: (Monad m) => Stream m a -> m ()
drain = Stream.fold Fold.drain

nonEmptyLines :: Stream IO (Array Word8) -> Stream IO String
nonEmptyLines inp =
    Unicode.decodeUtf8Chunks inp
        & Stream.foldMany (Fold.takeEndBy_ (== '\n') Fold.toList)
        & Stream.filter (not . null)

firstNonEmptyLine :: String -> Stream IO (Array Word8) -> IO String
firstNonEmptyLine tag =
    Stream.fold (maybe (error [str|Empty: #{tag}|]) id <$> Fold.one)
        . nonEmptyLines

printVar :: String -> String -> IO ()
printVar tag val = putStrLn [str|[#{tag}]: #{val}|]

ensureBlankWorkDir :: IO ()
ensureBlankWorkDir = do
    Cmd.toStdout [str|rm -rf #{env_POPULATE_WORK_DIR}|]
    Cmd.toStdout [str|mkdir -p #{env_POPULATE_WORK_DIR}|]

waitTillExists :: String -> IO ()
waitTillExists utxo =
    Stream.repeatM (printStep "Waiting" >> threadDelay 3000000 >> nullUtxo utxo)
        & Stream.takeWhile id
        & Stream.fold Fold.drain

fstOutput :: String -> String
fstOutput txid = [str|#{txid}#0|]

hexify :: String -> IO String
hexify val =
    Cmd.toChars [str|printf "%s" "#{val}"|]
        & Cmd.pipeChars "xxd -p"
        & Stream.takeWhile (/= '\n')
        & Stream.fold Fold.toList

-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------

{- HLINT ignore "Use camelCase" -}

env_POPULATE_WORK_DIR :: FilePath
env_POPULATE_WORK_DIR = "work"

env_TESTNET_WORK_DIR :: FilePath
env_TESTNET_WORK_DIR = "devnet-env"

env_LOCAL_CONFIG_DIR :: FilePath
env_LOCAL_CONFIG_DIR = "local-config"

env_PLUTUS_SCRIPTS_DIR :: FilePath
env_PLUTUS_SCRIPTS_DIR = "plutus-scripts"

env_CARDANO_TESTNET_NUM_NODES :: Int
env_CARDANO_TESTNET_NUM_NODES = 12

env_NODE1_SOCKET :: FilePath
env_NODE1_SOCKET = env_TESTNET_WORK_DIR </> "socket/node1/sock"

env_NODE2_SOCKET :: FilePath
env_NODE2_SOCKET = env_TESTNET_WORK_DIR </> "socket/node2/sock"

env_CARDANO_TESTNET_MAGIC :: Int
env_CARDANO_TESTNET_MAGIC = 42

env_FAUCET_WALLET_VKEY_FILE :: FilePath
env_FAUCET_WALLET_VKEY_FILE = env_TESTNET_WORK_DIR </> "utxo-keys/utxo1/utxo.vkey"

env_FAUCET_WALLET_SKEY_FILE :: FilePath
env_FAUCET_WALLET_SKEY_FILE = env_TESTNET_WORK_DIR </> "utxo-keys/utxo1/utxo.skey"

env_FAUCET_WALLET_ADDR :: IO String
env_FAUCET_WALLET_ADDR =
    readFile $ env_TESTNET_WORK_DIR </> "utxo-keys/utxo1/utxo.addr"

env_FAUCET_WALLET :: IO Wallet
env_FAUCET_WALLET =
    Wallet env_FAUCET_WALLET_VKEY_FILE env_FAUCET_WALLET_SKEY_FILE
        <$> env_FAUCET_WALLET_ADDR

env_TX_UNSIGNED :: String
env_TX_UNSIGNED = env_POPULATE_WORK_DIR </> "tx.unsigned"

env_TX_SIGNED :: String
env_TX_SIGNED = env_POPULATE_WORK_DIR </> "tx.signed"

-------------------------------------------------------------------------------
-- Command
-------------------------------------------------------------------------------

type Command = String

data CmdOption
    = CoOpt String String
    | CoFlg String
    | CoRaw String

opt :: (Show b) => String -> b -> CmdOption
opt a b = CoOpt a (quoted b)
  where
    quoted = show

flg :: String -> CmdOption
flg = CoFlg

raw :: String -> CmdOption
raw = CoRaw

optNetwork :: CmdOption
optNetwork = opt "testnet-magic" env_CARDANO_TESTNET_MAGIC

optNode1Socket :: CmdOption
optNode1Socket = opt "socket-path" env_NODE1_SOCKET

optNode2Socket :: CmdOption
optNode2Socket = opt "socket-path" env_NODE2_SOCKET

runCmd' :: String -> Stream IO (Array Word8)
runCmd' cmd = Stream.before (putStrLn [str|> #{cmd}|]) (Cmd.toChunks cmd)

runCmd_ :: String -> IO ()
runCmd_ cmd = do
    putStrLn [str|> #{cmd}|]
    Cmd.toStdout cmd

runCmd :: Command -> [CmdOption] -> Stream IO (Array Word8)
runCmd cmd args = runCmd' cmdStr
  where
    cmdOptStr (CoOpt k v) = [str|--#{k} #{v}|]
    cmdOptStr (CoFlg k) = [str|--#{k}|]
    cmdOptStr (CoRaw v) = v

    cmdList = cmd : map cmdOptStr args
    cmdStr = unwords cmdList

getPolicyId :: FilePath -> IO String
getPolicyId scriptFile =
    runCmd
        "cardano-cli conway transaction policyid"
        [opt "script-file" scriptFile]
        & firstNonEmptyLine "getPolicyId"

getAddress :: FilePath -> IO String
getAddress vkeyFile =
    runCmd
        "cardano-cli conway address build"
        [ optNetwork
        , opt "payment-verification-key-file" vkeyFile
        ]
        & firstNonEmptyLine "getAddress"

getScriptAddress :: FilePath -> IO String
getScriptAddress scriptFile =
    runCmd
        "cardano-cli conway address build"
        [ optNetwork
        , opt "payment-script-file" scriptFile
        ]
        & firstNonEmptyLine "getScriptAddress"

buildTransaction :: [CmdOption] -> IO ()
buildTransaction args =
    runCmd
        "cardano-cli conway transaction build"
        (optNetwork : optNode2Socket : args)
        & drain

signTransaction :: [CmdOption] -> IO ()
signTransaction args =
    runCmd
        "cardano-cli conway transaction sign"
        (optNetwork : args)
        & drain

submitTransaction :: [CmdOption] -> IO ()
submitTransaction args =
    runCmd
        "cardano-cli conway transaction submit"
        (optNetwork : optNode2Socket : args)
        & drain

buildStakeAddress :: [CmdOption] -> IO ()
buildStakeAddress args =
    runCmd
        "cardano-cli conway stake-address build"
        (optNetwork : args)
        & drain

genRegCertStakeAddress :: [CmdOption] -> IO ()
genRegCertStakeAddress args =
    runCmd "cardano-cli conway stake-address registration-certificate" args
        & drain

genDeregCertStakeAddress :: [CmdOption] -> IO ()
genDeregCertStakeAddress args =
    runCmd "cardano-cli conway stake-address deregistration-certificate" args
        & drain

getTransactionId :: String -> IO String
getTransactionId txSigned =
    runCmd
        "cardano-cli conway transaction txid"
        [ opt "tx-body-file" txSigned
        ]
        & Cmd.pipeChunks [str|jq -r ".txhash"|]
        & firstNonEmptyLine "getTransactionId"

getFirstUtxoAt :: String -> IO String
getFirstUtxoAt walletAddr =
    runCmd
        "cardano-cli conway query utxo"
        [ optNetwork
        , optNode2Socket
        , opt "address" walletAddr
        ]
        & Cmd.pipeChunks [str|jq -r "keys[0]"|]
        & firstNonEmptyLine "getFirstUtxoAt"

getUtxoListAt :: String -> IO [String]
getUtxoListAt walletAddr =
    runCmd
        "cardano-cli conway query utxo"
        [ optNetwork
        , optNode2Socket
        , opt "address" walletAddr
        ]
        & Cmd.pipeChunks [str|jq -r "keys[]"|]
        & nonEmptyLines
        & Stream.fold Fold.toList

nullUtxo :: String -> IO Bool
nullUtxo utxo =
    runCmd
        "cardano-cli latest query utxo"
        [ optNetwork
        , optNode2Socket
        , opt "tx-in" utxo
        ]
        & Cmd.pipeChunks [str|jq 'type == "object" and length == 0'|]
        & firstNonEmptyLine "nullUtxo"
        & fmap (== "true")

keygen :: FilePath -> FilePath -> IO ()
keygen vkey skey =
    runCmd
        "cardano-cli address key-gen"
        [ opt "verification-key-file" vkey
        , opt "signing-key-file" skey
        ]
        & drain

data Wallet
    = Wallet
    { wVKeyFile :: FilePath
    , wSKeyFile :: FilePath
    , wAddress :: String
    }

mkWallet :: FilePath -> String -> IO Wallet
mkWallet dir name = do
    let vkey = dir </> name <.> "vkey"
        skey = dir </> name <.> "skey"
    keygen vkey skey
    addr <- getAddress vkey
    pure $ Wallet vkey skey addr

walletKeyHash :: Wallet -> IO String
walletKeyHash Wallet{..} =
    runCmd
        "cardano-cli address key-hash"
        [ opt "payment-verification-key-file" wVKeyFile
        ]
        & firstNonEmptyLine "walletKeyHash"

fetchWallet :: FilePath -> String -> IO Wallet
fetchWallet dir name = do
    let vkey = dir </> name <.> "vkey"
        skey = dir </> name <.> "skey"
    addr <- getAddress vkey
    pure $ Wallet vkey skey addr

--------------------------------------------------------------------------------
-- Complex Utils
--------------------------------------------------------------------------------

transferAda :: Wallet -> Wallet -> Int -> IO String
transferAda (Wallet _ inSign inAddr) (Wallet _ outSign outAddr) adaToTransfer = do
    ensureBlankWorkDir
    utxoList <- getUtxoListAt inAddr
    let txInList = opt "tx-in" <$> utxoList
        adaStr = show adaToTransfer
    buildTransaction . (txInList ++) $
        [ opt "tx-out" [str|#{outAddr} + #{adaStr}|]
        , opt "change-address" inAddr
        , opt "out-file" env_TX_UNSIGNED
        ]
    signTransaction
        [ opt "signing-key-file" inSign
        , opt "signing-key-file" outSign
        , opt "tx-body-file" env_TX_UNSIGNED
        , opt "out-file" env_TX_SIGNED
        ]
    txId <- getTransactionId env_TX_SIGNED
    printVar "transferAda.txId" txId
    submitTransaction
        [ opt "tx-file" env_TX_SIGNED
        ]
    waitTillExists $ fstOutput txId
    pure txId

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

--------------------------------------------------------------------------------
-- Telemetry
--------------------------------------------------------------------------------

socketFile :: Int -> FilePath
socketFile i = [str|#{env_TESTNET_WORK_DIR}/socket/#{nodeDir}/sock|]
  where
    nodeDir = "node" ++ show i

getTipBlockNo :: FilePath -> IO (String, String)
getTipBlockNo socketPath = do
    res <-
        runCmd
            "cardano-cli query tip"
            [ optNetwork
            , opt "socket-path" socketPath
            ]
            & Cmd.pipeChunks [str|jq -r '.block,.hash'|]
            & nonEmptyLines
            & Stream.fold Fold.toList
    case res of
        [b, h] -> pure (b, h)
        _ -> error [str|getTipBlockNo: Unable to parse block and hash.|]

getNodeTips :: IO ()
getNodeTips = do
    res <- mapM getTipBlockNo_ [1..env_CARDANO_TESTNET_NUM_NODES]
    putStrLn divider
    putStrLn $ unlines res
  where
    getTipBlockNo_ i = do
        (b, h) <- getTipBlockNo (socketFile i)
        let iStr = show i
        pure [str|#{iStr} -> #{b}, #{h}|]

--------------------------------------------------------------------------------
-- Toxicity
--------------------------------------------------------------------------------

topologyFile :: Int -> FilePath
topologyFile i =
    [str|#{env_TESTNET_WORK_DIR}/node-data/#{nodeDir}/topology.json|]
  where
    nodeDir = "node" ++ show i

getConnectedPorts :: Int -> IO [String]
getConnectedPorts nodeNum = do
    nodeDirP <- Path.fromString (topologyFile nodeNum)
    File.readChunks nodeDirP
        & Cmd.pipeChunks [str|jq -r '.localRoots[].accessPoints[].port'|]
        & nonEmptyLines
        & Stream.fold Fold.toList

type Port = String

nodeNeighboursM :: Int -> IO [Port]
nodeNeighboursM = getConnectedPorts

nodePortsOrderedM :: IO [Port]
nodePortsOrderedM = do
    nn1 <- nodeNeighboursM 1
    nn2 <- nodeNeighboursM 2
    pure $ (nn2 \\ nn1) ++ nn1

nodePortMappingM :: IO (IntMap Port)
nodePortMappingM = do
    npo <- nodePortsOrderedM
    pure $ IntMap.fromAscList $ zip [1..] npo

proxyMappingM :: IO (Map Port Port)
proxyMappingM = do
    npo <- nodePortsOrderedM
    pure $ Map.fromList $ zip npo (map show ([5001, 5002..] :: [Int]))

saveMappings :: IO ()
saveMappings = do
    writeFile (env_TESTNET_WORK_DIR </> "nodePortMapping.data") . show =<< nodePortMappingM
    writeFile (env_TESTNET_WORK_DIR </> "proxyMapping.data") . show =<< proxyMappingM

readNodePortMapping :: IO (IntMap Port)
readNodePortMapping =
    read <$> readFile (env_TESTNET_WORK_DIR </> "nodePortMapping.data")

readProxyMapping :: IO (Map Port Port)
readProxyMapping =
    read <$> readFile (env_TESTNET_WORK_DIR </> "proxyMapping.data")

-- NOTE: This is a little hacky but it's alright for now.
-- TODO: Clean it up and make it robust.
-- TODO: Make this more robust by using jq or aeson.
replaceNeighboursWithProxy :: Map Port Port -> Int -> IO ()
replaceNeighboursWithProxy proxyMapping i =
    Map.foldrWithKey foldFunc (pure ()) proxyMapping
  where
    topologyFileS = topologyFile i
    foldFunc orig prxy act = do
        act
        runCmd_ [str|sed -i 's/#{orig}/#{prxy}/g' #{topologyFileS}|]

replaceAllNeighboursWithProxy :: IO ()
replaceAllNeighboursWithProxy = do
    proxyMapping <- readProxyMapping
    flip mapM_ [1..env_CARDANO_TESTNET_NUM_NODES] $
        replaceNeighboursWithProxy proxyMapping

toxiproxyCreate :: IntMap Port -> Map Port Port -> Int -> IO ()
toxiproxyCreate nodePortMapping proxyMapping i =
    runCmd_ [str|toxiproxy-cli create --listen 127.0.0.1:#{l} --upstream 127.0.0.1:#{u} #{n}|]
  where
    n = "node" ++ show i
    u = maybe (error "toxiproxyCreate: Unknown Port") id $ IntMap.lookup i nodePortMapping
    l = maybe (error "toxiproxyCreate: Unknown Proxy") id $ Map.lookup u proxyMapping

toxiproxyCreateClients :: IO ()
toxiproxyCreateClients = do
    proxyMapping <- readProxyMapping
    nodePortMapping <- readNodePortMapping
    flip mapM_ [1..env_CARDANO_TESTNET_NUM_NODES] $
        toxiproxyCreate nodePortMapping proxyMapping

toxiproxyServer :: IO ()
toxiproxyServer =
    runCmd' "toxiproxy-server"
        & Stream.fold Stdio.writeChunks

--------------------------------------------------------------------------------
-- Toxicity combinators
--------------------------------------------------------------------------------

data NetworkDirection = Upstream | Downstream

data ToxLatencyOpts =
    ToxLatencyOpts
        { tloLatency :: Int
        , tloJitter :: Int
        }

toxLatency :: String -> NetworkDirection -> ToxLatencyOpts -> Int -> IO ()
toxLatency name ndir opts i =
    runCmd_ [str|toxiproxy-cli toxic add -n #{name} -t latency #{direction} #{attrs} #{proxyName}|]
  where
    latency = show (tloLatency opts)
    jitter = show (tloJitter opts)
    direction =
        case ndir of
            Upstream -> "-u"
            Downstream -> "-d"
    attrs = [str|-a latency=#{latency} -a jitter=#{jitter}|]
    proxyName = "node" ++ show i

toxRemove :: String -> Int -> IO ()
toxRemove name i = do
    let proxyName = "node" ++ show i
    runCmd_ [str|toxiproxy-cli toxic remove -n #{name} #{proxyName}|]

addToxicity :: IO ()
addToxicity = do
    let degradedNodes = [1..(div env_CARDANO_TESTNET_NUM_NODES 2)]
    mapM_ (toxLatency "t1" Upstream (ToxLatencyOpts 5000 100)) degradedNodes

removeToxicity :: IO ()
removeToxicity = do
    let degradedNodes = [1..(div env_CARDANO_TESTNET_NUM_NODES 2)]
    mapM_ (toxRemove "t1") degradedNodes
