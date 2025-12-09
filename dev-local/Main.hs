{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Main (main) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Control.Monad (when)
import Data.Function ((&))

import Options.Applicative hiding (str)
import Populate
import Streamly.Console.Stdio qualified as Console
import Streamly.FileSystem.FileIO qualified as File
import Streamly.FileSystem.Path qualified as Path
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.String (str)
import System.Environment (setEnv)
import System.FilePath ((</>))
import System.IO (BufferMode (..), hSetBuffering, stderr, stdout)

-------------------------------------------------------------------------------
-- CLI
-------------------------------------------------------------------------------

data PopulateCommand
    = PCTriggerTest
    | PCEscrow
    | PCFanout

data Command
    = StartLocalTestnet
    | Clean
    | Populate PopulateCommand
    | Setup
    | SyncNodes
    | ToxiproxyServer
    | GetNodeTips
    | AddToxicity
    | RemoveToxicity

populateCommandParser :: Parser PopulateCommand
populateCommandParser =
    hsubparser
        ( command
            "trigger-test"
            ( info
                (pure PCTriggerTest)
                (progDesc "Run the trigger test")
            )
            <> command
                "escrow"
                ( info
                    (pure PCEscrow)
                    (progDesc "Run the escrow scenario")
                )
            <> command
                "fanout"
                ( info
                    (pure PCFanout)
                    (progDesc "Run the fanout scenario")
                )
        )
commandParser :: Parser Command
commandParser =
    hsubparser
        ( command
            "start-local-testnet"
            ( info
                (pure StartLocalTestnet)
                (progDesc "Start the local development network")
            )
            <> command
                "clean"
                ( info
                    (pure Clean)
                    (progDesc "Clean all local state")
                )
            <> command
                "populate"
                ( info
                    (Populate <$> populateCommandParser)
                    (progDesc "Populate the local network with initial data")
                )
            <> command
                "setup"
                ( info
                    (pure Setup)
                    (progDesc "Setup the initial config files")
                )
            <> command
                "sync-nodes"
                ( info
                    (pure SyncNodes)
                    (progDesc "Sync nodes with proxies")
                )
            <> command
                "toxiproxy-server"
                ( info
                    (pure ToxiproxyServer)
                    (progDesc "Start toxiproxy server")
                )
            <> command
                "get-node-tips"
                ( info
                    (pure GetNodeTips)
                    (progDesc "Start toxiproxy server")
                )
            <> command
                "add-toxicity"
                ( info
                    (pure AddToxicity)
                    (progDesc "Add toxicity")
                )
            <> command
                "remove-toxicity"
                ( info
                    (pure RemoveToxicity)
                    (progDesc "Remove toxicity")
                )
        )

opts :: ParserInfo Command
opts =
    info
        (commandParser <**> helper)
        ( fullDesc
            <> progDesc "Local development management tool"
        )

--------------------------------------------------------------------------------
-- Create config
--------------------------------------------------------------------------------

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

createConfig :: IO ()
createConfig = do
    runCmd_ [str|mkdir -p #{env_LOCAL_CONFIG_DIR}|]
    createTracingConfig alwaysTrueV3 alwaysTrueV3 "tracing-plutus-v3"
    createTracingConfig alwaysTruePolicyV2 alwaysTrueValidatorV2 "tracing-plutus-v2"

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

changeSecurityParam :: Int -> IO ()
changeSecurityParam i = do
    -- NOTE: Using jq here fails because of runCmd. Need to investigate this
    -- later.
    -- TODO: Use jq instead of sed
    updateAndCheck
        shelly
        [str|s/"securityParam": [0-9]*/"securityParam": #{secParam}/|]
        ".securityParam"
    updateAndCheck byron [str|s/"k": [0-9]*/"k": #{secParam}/|] ".protocolConsts.k"
  where
    updateAndCheck fp sedQ jqQ = do
        runCmd_ [str|sed -i '#{sedQ}' #{fp}|]
        fpP <- Path.fromString fp
        updated <-
            File.readChunks fpP
                & Cmd.pipeChunks [str|jq -r "#{jqQ}"|]
                & firstNonEmptyLine "changeSecurityParam.updateAndCheck"
        when (updated /= secParam) . error $
            "changeSecurityParam: Unable to change security param: " ++ fp

    shelly = env_TESTNET_WORK_DIR </> "shelley-genesis.json"
    byron = env_TESTNET_WORK_DIR </> "byron-genesis.json"
    secParam = show i

createTestnetConfig :: IO ()
createTestnetConfig = do
    runCmd
        "cardano-testnet create-env"
        [ opt "num-pool-nodes" env_CARDANO_TESTNET_NUM_NODES
        , opt "num-dreps" env_CARDANO_TESTNET_NUM_NODES
        , flg "enable-new-epoch-state-logging"
        , opt "output" env_TESTNET_WORK_DIR
        , opt "testnet-magic" env_CARDANO_TESTNET_MAGIC
        ]
        & Console.putChunks
    changeSecurityParam 100
    saveMappings
    replaceAllNeighboursWithProxy

startLocalTestnet :: IO ()
startLocalTestnet = do
    runCmd
        "cardano-testnet cardano"
        [ opt "num-pool-nodes" env_CARDANO_TESTNET_NUM_NODES
        , flg "enable-new-epoch-state-logging"
        , opt "node-env" env_TESTNET_WORK_DIR
        , opt "testnet-magic" env_CARDANO_TESTNET_MAGIC
        ]
        & Console.putChunks

clean :: IO ()
clean = do
    runCmd_ [str|rm -rf #{env_LOCAL_CONFIG_DIR}|]
    runCmd_ [str|rm -rf #{env_TESTNET_WORK_DIR}|]
    runCmd_ [str|rm -rf #{env_POPULATE_WORK_DIR}|]

setup :: IO ()
setup = do
    clean
    createConfig
    createTestnetConfig

main :: IO ()
main = do
    hSetBuffering stdout LineBuffering
    hSetBuffering stderr LineBuffering
    cmd <- execParser opts

    setEnv "CARDANO_CLI" "cardano-cli"
    setEnv "CARDANO_NODE" "cardano-node"
    case cmd of
        StartLocalTestnet -> startLocalTestnet
        Clean -> clean
        Populate PCTriggerTest -> testScriptTrigger
        Populate PCEscrow -> escrow
        Populate PCFanout -> runFanout
        Setup -> setup
        SyncNodes -> toxiproxyCreateClients
        ToxiproxyServer -> toxiproxyServer
        GetNodeTips -> getNodeTips
        AddToxicity -> addToxicity
        RemoveToxicity -> removeToxicity
