{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Main (main) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Control.Monad (when)
import Data.Function ((&))
import Data.List qualified as List

import Options.Applicative hiding (str)
import Streamly.Console.Stdio qualified as Console
import Streamly.Data.Stream qualified as Stream
import Streamly.FileSystem.FileIO qualified as File
import Streamly.FileSystem.Path qualified as Path
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.String (str)
import System.Environment (setEnv, lookupEnv)
import System.FilePath ((</>))
import System.IO (BufferMode (..), hSetBuffering, stderr, stdout)
import UI qualified as UI

import Misc
import Populate
import Network
import Gov

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

data Command
    = StartLocalTestnet
    | Clean
    | Populate PopulateCommand
    | Setup
    | Network NetworkCommand
    | StdoutComposeYaml String
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
    configTmpP <- Path.fromString configTmp
    runCmd [str|jq '.ExperimentalHardForksEnabled = true' #{config}|] []
        & Stream.fold (File.writeChunks configTmpP)
    runCmd_ [str|mv #{configTmp} #{config}|]
    when startDirectlyInDijkstra $ do
        runCmd [str|jq '.TestDijkstraHardForkAtEpoch = 0' #{config}|] []
            & Stream.fold (File.writeChunks configTmpP)
        runCmd_ [str|mv #{configTmp} #{config}|]
  where
    startDirectlyInDijkstra = True
    configTmp = env_TESTNET_WORK_DIR </> "configuration.yaml.tmp"
    config = env_TESTNET_WORK_DIR </> "configuration.yaml"

updateParamAndCheck :: FilePath -> String -> String -> String -> IO ()
updateParamAndCheck fp sedQ jqQ newParam = do
    runCmd_ [str|sed -i '#{sedQ}' #{fp}|]
    fpP <- Path.fromString fp
    updated <-
        File.readChunks fpP
            & Cmd.pipeChunks [str|jq -r "#{jqQ}"|]
            & firstNonEmptyLine "updateParamAndCheck"
    when (updated /= newParam) . error $
        "updateParamAndCheck: Unable to change param: " ++ fp

changeEpochLength :: Int -> IO ()
changeEpochLength secs =
    updateParamAndCheck
        shelley
        [str|s/"epochLength": [0-9]*/"epochLength": #{targetVal}/|]
        ".epochLength"
        targetVal
  where
    shelley = env_TESTNET_WORK_DIR </> "shelley-genesis.json"
    targetVal = show secs

changeSlotLength :: Double -> IO ()
changeSlotLength i =
    updateParamAndCheck
        shelley
        [str|s/"slotLength": [0-9\.]*/"slotLength": #{targetVal}/|]
        ".slotLength"
        targetVal
  where
    shelley = env_TESTNET_WORK_DIR </> "shelley-genesis.json"
    targetVal = show i

changeSecurityParam :: Int -> IO ()
changeSecurityParam i = do
    -- NOTE: Using jq here fails because of runCmd. Need to investigate this
    -- later.
    -- TODO: Use jq instead of sed
    updateParamAndCheck
        shelly
        [str|s/"securityParam": [0-9]*/"securityParam": #{secParam}/|]
        ".securityParam"
        secParam
    updateParamAndCheck
        byron
        [str|s/"k": [0-9]*/"k": #{secParam}/|] ".protocolConsts.k"
        secParam
  where
    shelly = env_TESTNET_WORK_DIR </> "shelley-genesis.json"
    byron = env_TESTNET_WORK_DIR </> "byron-genesis.json"
    secParam = show i

createTestnetConfig :: IO ()
createTestnetConfig = do
    let
      nodesArg = concat $ List.intersperse "," $
            [ "spo" | _ <- [1..env_CARDANO_TESTNET_NUM_SPO_NODES]] ++
            [ "relay" | _ <- [1..env_CARDANO_TESTNET_NUM_RELAY_NODES]]
    runCmd
        [str|#{cardanoTestnet} create-env|]
        [ opt "nodes" nodesArg
        , opt "num-dreps" env_CARDANO_TESTNET_NUM_RELAY_NODES
        , opt "output" env_TESTNET_WORK_DIR
        , opt "testnet-magic" env_CARDANO_TESTNET_MAGIC
        ]
        & Console.putChunks
    changeSecurityParam 5
    changeEpochLength 120
    changeSlotLength 0.1
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

#{nodeLogProcessAll}

|]
  where
    nodeLogProcess i0 = let i = show i0 in [str|
  node-stdout-#{i}:
    command: "tail -f ./#{env_TESTNET_WORK_DIR}/logs/node#{i}/stdout.log | grep --line-buffered -E 'TraceObjectDiffusion|PerasVoteDbEvent'"
    depends_on:
      cardano-testnet:
        condition: process_healthy
|]
    nodeLogProcessAll =
        unlines $ nodeLogProcess <$> [1..env_CARDANO_TESTNET_NUM_NODES]

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
        StdoutComposeYaml testnetCmd -> stdoutComposeYaml testnetCmd
        UI -> UI.main

setEnvIfDoesNotExist :: String -> String -> IO ()
setEnvIfDoesNotExist key val = do
    existing <- lookupEnv key
    case existing of
        Nothing -> setEnv key val
        Just _ -> pure ()
