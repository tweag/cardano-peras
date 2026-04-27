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
import Streamly.Console.Stdio qualified as Console
import Streamly.FileSystem.FileIO qualified as File
import Streamly.FileSystem.Path qualified as Path
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.String (str)
import System.Environment (setEnv)
import System.FilePath ((</>))
import System.IO (BufferMode (..), hSetBuffering, stderr, stdout)

import Misc
import Populate
import Network

-------------------------------------------------------------------------------
-- CLI
-------------------------------------------------------------------------------

data PopulateCommand
    = PCTriggerTest
    | PCEscrow
    | PCFanout

data NetworkCommand
    = NCSyncNodes
    | NCToxiproxyServer
    | NCGetNodeTips
    | NCAddToxicity
    | NCRemoveToxicity

data Command
    = StartLocalTestnet
    | Clean
    | Populate PopulateCommand
    | Setup
    | Network NetworkCommand
    | StdoutComposeYaml String


networkCommandParser :: Parser NetworkCommand
networkCommandParser =
    hsubparser
        ( command
                "sync-nodes"
                ( info
                    (pure NCSyncNodes)
                    (progDesc "Sync nodes with proxies")
                )
            <> command
                "toxiproxy-server"
                ( info
                    (pure NCToxiproxyServer)
                    (progDesc "Start toxiproxy server")
                )
            <> command
                "get-node-tips"
                ( info
                    (pure NCGetNodeTips)
                    (progDesc "Start toxiproxy server")
                )
            <> command
                "add-toxicity"
                ( info
                    (pure NCAddToxicity)
                    (progDesc "Add toxicity")
                )
            <> command
                "remove-toxicity"
                ( info
                    (pure NCRemoveToxicity)
                    (progDesc "Remove toxicity")
                )
        )

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
                "network"
                ( info
                    (Network <$> networkCommandParser)
                    (progDesc "Simulate Network")
                )
            <> command
                "setup"
                ( info
                    (pure Setup)
                    (progDesc "Setup the initial config files")
                )
            <> command
                "stdout-compose-yaml"
                ( info
                    (StdoutComposeYaml <$> strArgument mempty)
                    (progDesc "Contents of process-compose.yaml")
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
    savePortAndProxyMappings
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
    createPopulateConfig
    createTestnetConfig

stdoutComposeYaml :: String -> IO ()
stdoutComposeYaml testnetCmd = putStr [str|
version: "0.5"

processes:
  setup:
    command: "#{testnetCmd} setup"

  cardano-testnet:
    command: "#{testnetCmd} start-local-testnet"
    depends_on:
      setup:
        condition: process_completed_successfully
    readiness_probe:
      exec:
        command: "[ -S ./#{env_TESTNET_WORK_DIR}/socket/node1/sock ]"
      initial_delay_seconds: 1
      period_seconds: 1
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 60

  get-node-tips:
    command: "#{testnetCmd} network get-node-tips"
    disabled: true

  add-toxicity:
    command: "#{testnetCmd} network add-toxicity"
    disabled: true

  remove-toxicity:
    command: "#{testnetCmd} network remove-toxicity"
    disabled: true

  sync-nodes:
    command: "#{testnetCmd} network sync-nodes"
    depends_on:
      toxiproxy-server:
        condition: process_healthy

  toxiproxy-server:
    command: "#{testnetCmd} network toxiproxy-server"
    depends_on:
      cardano-testnet:
        condition: process_healthy
    readiness_probe:
      exec:
        command: "curl -sf http://127.0.0.1:8474/proxies"
      initial_delay_seconds: 1
      period_seconds: 2
      timeout_seconds: 1
      success_threshold: 1
      failure_threshold: 5
|]

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
        Network NCSyncNodes -> toxiproxyCreateClients
        Network NCToxiproxyServer -> toxiproxyServer
        Network NCGetNodeTips -> getNodeTips
        Network NCAddToxicity -> addToxicity
        Network NCRemoveToxicity -> removeToxicity
        StdoutComposeYaml testnetCmd -> stdoutComposeYaml testnetCmd
