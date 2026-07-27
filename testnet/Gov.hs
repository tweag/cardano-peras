{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Gov (
    governProtocolUpdateTo12
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Misc
import Streamly.Unicode.String (str)
import System.FilePath ((</>), (-<.>))
import Populate (finalizeCurrentTransaction)
import Control.Concurrent (threadDelay)

-------------------------------------------------------------------------------
-- Gov
-------------------------------------------------------------------------------

-- TODO: Remove duplication.
alwaysTrueV3 :: String
alwaysTrueV3 = [str|
{
    "type": "PlutusScriptV3",
    "description": "",
    "cborHex": "450101002499"
}
|]

governProtocolUpdateTo12 :: IO ()
governProtocolUpdateTo12 = do
    faucetAddr <- env_FAUCET_WALLET_ADDR

    let stakeScriptFile = env_LOCAL_CONFIG_DIR </> "always-true-v3.plutus"
    writeFile stakeScriptFile alwaysTrueV3

    registerStakeScipt faucetAddr stakeScriptFile
    waitTill "protocol.major == 10" ((== 10) <$> getProtocolMajorVersion)
    threadDelay 5000000
    runGovAction faucetAddr stakeScriptFile 11 >>= createVotes faucetAddr
    waitTill "protocol.major == 11" ((== 11) <$> getProtocolMajorVersion)
    threadDelay 5000000
    runGovAction faucetAddr stakeScriptFile 12 >>= createVotes faucetAddr
    waitTill "protocol.major == 12" ((== 12) <$> getProtocolMajorVersion)

  where

    vKeyPool iStr = env_TESTNET_WORK_DIR </> "pools-keys" </> [str|pool#{iStr}|] </> "cold.vkey"
    vKeyDrep iStr = env_TESTNET_WORK_DIR </> "drep-keys"</> [str|drep#{iStr}|]</> "drep.vkey"
    getSkey = (-<.> "skey")

    createVotes faucetAddr govTxId = do
        ensureBlankWorkDir
        faucetUtxo <- getFirstUtxoAt faucetAddr
        let nodes = map show [1..env_CARDANO_TESTNET_NUM_NODES]
        nodeVotes <- mapM (createPoolVote govTxId) nodes
        drepVotes <- mapM (createDrepVote govTxId) nodes
        let allVotes = nodeVotes ++ drepVotes
            allVotesSigners = getSkey <$> concat
                [ vKeyPool <$> nodes
                , vKeyDrep <$> nodes
                ]
        buildTransaction $ concat
            [ opt "vote-file" <$> allVotes
            , [ opt "tx-in" faucetUtxo
              , opt "change-address" faucetAddr
              , opt "out-file" env_TX_UNSIGNED
              ]
            ]
        signTransaction $ concat
            [ opt "signing-key-file" <$> allVotesSigners
            , [ opt "signing-key-file" env_FAUCET_WALLET_SKEY_FILE
              , opt "tx-body-file" env_TX_UNSIGNED
              , opt "out-file" env_TX_SIGNED
              ]
            ]
        submitTransaction
            [ opt "tx-file" env_TX_SIGNED
            ]
        txId <- getTransactionId env_TX_SIGNED
        waitTillExists $ fstOutput txId

    createPoolVote govTxId iStr = do
        let poolKey = vKeyPool iStr
            outFile = env_LOCAL_CONFIG_DIR </> [str|pool#{iStr}.vote|]
        govVoteCreate
            [ flg "yes"
            , opt "governance-action-tx-id" govTxId
            , opt "governance-action-index" (0 :: Int)
            , opt "cold-verification-key-file" poolKey
            , opt "out-file" outFile
            ]
        pure outFile

    createDrepVote govTxId iStr = do
        let drepKey = vKeyDrep iStr
            outFile = env_LOCAL_CONFIG_DIR </> [str|drep#{iStr}.vote|]
        govVoteCreate
            [ flg "yes"
            , opt "governance-action-tx-id" govTxId
            , opt "governance-action-index" (0 :: Int)
            , opt "drep-verification-key-file" drepKey
            , opt "out-file" outFile
            ]
        pure outFile

    runGovAction faucetAddr stakeScriptFile protoMajorVersion = do
        let actionOutFile = env_LOCAL_CONFIG_DIR </> "hardfork.action"
        ensureBlankWorkDir
        faucetUtxo <- getFirstUtxoAt faucetAddr
        mPrevGovTxId <- govQueryPrevHardforkActionTxId
        printVar "faucetUtxo" faucetUtxo
        govActionHarkFork $ concat
            [ [ opt "governance-action-deposit" (1000000 :: Int)
              , opt "deposit-return-stake-script-file" stakeScriptFile
              , optAnchorUrl
              , optAnchorDataHash
              , opt "protocol-major-version" (protoMajorVersion :: Int)
              , opt "protocol-minor-version" (0 :: Int)
              ]
            , case mPrevGovTxId of
                  Nothing -> []
                  Just prevGovTxId ->
                      [ opt "prev-governance-action-tx-id" prevGovTxId
                      , opt "prev-governance-action-index" (0 :: Int)
                      ]
            , [ opt "out-file" actionOutFile
              ]
            ]
        buildTransaction
            [ opt "tx-in" faucetUtxo
            , opt "proposal-file" actionOutFile
            , opt "change-address" faucetAddr
            , opt "out-file" env_TX_UNSIGNED
            ]
        finalizeCurrentTransaction
        txId <- getTransactionId env_TX_SIGNED
        waitTillExists $ fstOutput txId
        pure txId

    registerStakeScipt faucetAddr stakeScriptFile = do
        ensureBlankWorkDir
        let stakeCertFile = env_LOCAL_CONFIG_DIR </> "registration.cert"
        faucetUtxo <- getFirstUtxoAt faucetAddr
        printVar "faucetUtxo" faucetUtxo
        genRegCertStakeAddress
            [ opt "stake-script-file" stakeScriptFile
            , opt "out-file" stakeCertFile
            , opt "key-reg-deposit-amt" (400_000 :: Int)
            ]
        buildTransaction
            [ opt "tx-in" faucetUtxo
            , opt "tx-in-collateral" faucetUtxo
            , opt "certificate-file" stakeCertFile
            , opt "certificate-script-file" stakeScriptFile
            , opt "certificate-redeemer-value" ("{}" :: String)
            , opt "change-address" faucetAddr
            , opt "out-file" env_TX_UNSIGNED
            ]
        finalizeCurrentTransaction
        txObj <- getTransactionId env_TX_SIGNED
        waitTillExists $ fstOutput txObj
