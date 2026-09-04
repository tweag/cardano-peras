{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Main (main) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Data.Aeson (Value (..))
import Data.Function ((&))
import Data.List qualified as List
import Data.Scientific qualified as Scientific
import Data.Text qualified as Text

import Options.Applicative hiding (str)
import Streamly.Console.Stdio qualified as Console
import Streamly.Unicode.String (str)
import System.Environment (setEnv, lookupEnv)
import System.IO (BufferMode (..), hSetBuffering, stderr, stdout)
import UI qualified as UI

import JsonFile
import Misc
import Populate
import Network
import Gov
import Scenario
import Stake

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
    | NCHardForkToDijkstra
    | NCChairman
    | NCApplyFaults

data Command
    = StartLocalTestnet
    | Clean
    | Populate PopulateCommand
    | Setup
    | Network NetworkCommand
    | StdoutComposeYaml String
    | ValidateScenario FilePath
    | RedistributeStake
    | UI

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
            <> command
                "hard-fork-dijkstra"
                ( info
                    (pure NCHardForkToDijkstra)
                    (progDesc "Hard fork to dijkstra")
                )
            <> command
                "chairman"
                ( info
                    (pure NCChairman)
                    (progDesc "Watch all nodes and check they stay in consensus")
                )
            <> command
                "apply-faults"
                ( info
                    (pure NCApplyFaults)
                    (progDesc "Apply the faults defined in the active scenario (TESTNET_SCENARIO)")
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
            <> command
                "validate-scenario"
                ( info
                    (ValidateScenario <$> strArgument (metavar "FILE"))
                    (progDesc "Parse and validate a scenario YAML file")
                )
            <> command
                "redistribute-stake"
                ( info
                    (pure RedistributeStake)
                    (progDesc "Rebalance genesis stake per topology.groups[].stake (TESTNET_SCENARIO)")
                )
            <> command
                "ui"
                ( info
                    (pure UI)
                    (progDesc "User Interface")
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

setExperimentalHardForksEnabled :: IO ()
setExperimentalHardForksEnabled = do
    config <- readJsonFile configurationYamlFile
    let config' = setPath ["ExperimentalHardForksEnabled"] (Bool True) config
        config'' =
            if env_GENESIS_START_DIRECTLY_IN_DIJKSTRA
                then setPath ["TestDijkstraHardForkAtEpoch"] (Number 0) config'
                else config'
    writeJsonFile configurationYamlFile config''

changeEpochLength :: Int -> IO ()
changeEpochLength secs = do
    genesis <- readJsonFile shelleyGenesisFile
    writeJsonFile shelleyGenesisFile $
        setPath ["epochLength"] (Number (fromIntegral secs)) genesis

changeSlotLength :: Double -> IO ()
changeSlotLength secs = do
    genesis <- readJsonFile shelleyGenesisFile
    writeJsonFile shelleyGenesisFile $
        setPath ["slotLength"] (Number (Scientific.fromFloatDigits secs)) genesis

changeSecurityParam :: Int -> IO ()
changeSecurityParam k = do
    shelley <- readJsonFile shelleyGenesisFile
    writeJsonFile shelleyGenesisFile $
        setPath ["securityParam"] (Number (fromIntegral k)) shelley
    byron <- readJsonFile byronGenesisFile
    writeJsonFile byronGenesisFile $
        setPath ["protocolConsts", "k"] (Number (fromIntegral k)) byron

createTestnetConfig :: IO ()
createTestnetConfig = do
    let
      nodesArg = concat $ List.intersperse "," $
            [ "spo" | _ <- [1..env_CARDANO_TESTNET_NUM_SPO_NODES]] ++
            [ "relay" | _ <- [1..env_CARDANO_TESTNET_NUM_RELAY_NODES]]
    runCmd
        [str|#{cardanoTestnet} create-env|]
        [ opt "nodes" nodesArg
        , opt "num-dreps" env_GENESIS_NUM_DREPS
        , opt "max-lovelace-supply" env_GENESIS_MAX_LOVELACE_SUPPLY
        , opt "output" env_TESTNET_WORK_DIR
        , opt "testnet-magic" env_CARDANO_TESTNET_MAGIC
        ]
        & Console.putChunks
    changeSecurityParam env_GENESIS_SECURITY_PARAM_K
    changeEpochLength env_GENESIS_EPOCH_LENGTH_SLOTS
    changeSlotLength env_GENESIS_SLOT_LENGTH_SECONDS
    redistributeStake
    setExperimentalHardForksEnabled
    ports <- portsIO
    -- We only replace neighbors of node 1 with proxies for partitioning node 1
    replaceNeighboursWithProxy ports 1
    mapM_ (flip (replaceNeighbourWithProxy ports) 1) [2..env_CARDANO_TESTNET_NUM_NODES]

startLocalTestnet :: IO ()
startLocalTestnet = do
    runCmd
        [str|#{cardanoTestnet} cardano|]
        [ opt "node-env" env_TESTNET_WORK_DIR
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

-- TODO: Add a dependency between cardano-testnet and server
stdoutComposeYaml :: String -> String -> IO ()
stdoutComposeYaml scenarioName testnetCmd = putStr [str|
version: "0.5"
name: "testnet-#{scenarioName}"

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

  sync-nodes:
    command: "#{testnetCmd} network sync-nodes"
    depends_on:
      toxiproxy-server:
        condition: process_healthy

  hard-fork-dijkstra:
    command: "#{testnetCmd} network hard-fork-dijkstra"
    disabled: true

  chairman:
    command: "#{testnetCmd} network chairman"
    depends_on:
      cardano-testnet:
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

  apply-faults:
    command: "#{testnetCmd} network apply-faults"
    depends_on:
      sync-nodes:
        condition: process_completed_successfully

#{nodeLogProcessAll}

|]
  where
    traceFilterPattern =
        List.intercalate "|" (Text.unpack <$> observabilityTraceFilters (scenarioConfigObservability scenarioConfig))
    nodeLogProcess i0 = let i = show i0 in [str|
  node-stdout-#{i}:
    command: "tail -f ./#{env_TESTNET_WORK_DIR}/logs/node#{i}/stdout.log | grep --line-buffered -E '#{traceFilterPattern}'"
    depends_on:
      cardano-testnet:
        condition: process_healthy
|]
    nodeLogProcessAll =
        unlines $ nodeLogProcess <$> [1..env_CARDANO_TESTNET_NUM_NODES]

validateScenario :: FilePath -> IO ()
validateScenario path = do
    config <- loadScenario path
    putStrLn $ "Correct: " ++ path
    putStrLn $ "  name: " ++ Text.unpack (scenarioConfigName config)
    putStrLn $ "  groups: " ++ show (length (topologyGroups (scenarioConfigTopology config)))
    putStrLn $ "  nodes: " ++ show (sum (groupCount <$> topologyGroups (scenarioConfigTopology config)))
    putStrLn $ "  faults: " ++ show (length (scenarioConfigFaults config))

main :: IO ()
main = do
    hSetBuffering stdout LineBuffering
    hSetBuffering stderr LineBuffering
    cmd <- execParser opts

    setEnvIfDoesNotExist "CARDANO_CLI" "cardano-cli"
    setEnvIfDoesNotExist "CARDANO_NODE" "cardano-node"

    case cmd of
        StartLocalTestnet -> startLocalTestnet
        Clean -> clean
        Populate PCTriggerTest -> testScriptTrigger
        Populate PCEscrow -> escrow
        Populate PCFanout -> runFanout
        Setup -> setup
        Network NCSyncNodes -> toxiproxyCreateClients =<< portsIO
        Network NCToxiproxyServer -> toxiproxyServer
        Network NCGetNodeTips -> renderNodeTips
        Network NCAddToxicity -> addToxicity
        Network NCRemoveToxicity -> removeToxicity
        Network NCHardForkToDijkstra -> governProtocolUpdateTo12
        Network NCChairman -> runChairman
        Network NCApplyFaults -> applyFaults (scenarioConfigFaults scenarioConfig)
        StdoutComposeYaml testnetCmd -> stdoutComposeYaml (Text.unpack $ scenarioConfigName scenarioConfig) testnetCmd
        ValidateScenario path -> validateScenario path
        RedistributeStake -> redistributeStake
        UI -> UI.main

setEnvIfDoesNotExist :: String -> String -> IO ()
setEnvIfDoesNotExist key val = do
    existing <- lookupEnv key
    case existing of
        Nothing -> setEnv key val
        Just _ -> pure ()
