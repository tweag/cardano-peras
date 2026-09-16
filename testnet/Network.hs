{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Network (
    replaceAllNeighboursWithProxy,
    replaceNeighboursWithProxy,
    replaceNeighbourWithProxy,
    toxiproxyServer,
    toxiproxyCreateClients,
    getNodeTips,
    addToxicity,
    removeToxicity,
    ToxLatencyOpts (..),
    toxLatency,
    toxRemove,
    portsIO,
    NodeTip (..),
    renderNodeTips,
    runChairman,
    applyFaults,
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Misc
import Scenario (FaultAction(..))
import Scenario qualified as Scenario
import Streamly.Console.Stdio qualified as Stdio
import Data.Function ((&))
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream qualified as Stream
import Streamly.System.Command qualified as Cmd
import Streamly.Data.Array qualified as Array
import Streamly.Data.Array (Array)
import System.FilePath ((</>), (<.>))

--------------------------------------------------------------------------------
-- Toxicity
--------------------------------------------------------------------------------

nodeDataDir :: Int -> FilePath
nodeDataDir i = env_TESTNET_WORK_DIR </> "node-data" </> nodeName i

portFile :: Int -> FilePath
portFile i = nodeDataDir i </> "port"

topologyFile :: Int -> FilePath
topologyFile i = nodeDataDir i </> "topology" <.> "json"

type Port = Int

getOriginalNodePort :: Int -> IO Port
getOriginalNodePort = fmap read . readFile . portFile

portsIO :: IO (Array Port)
portsIO = do
    ports <- mapM getOriginalNodePort [1..env_CARDANO_TESTNET_NUM_NODES]
    putStrLn $ "Ports: " <> show ports
    pure $ Array.fromList ports


getProxyPort :: Int -> Port
getProxyPort = (+ 5000)

-- NOTE: This is a little hacky but it's alright for now.
-- TODO: Clean it up and make it robust.
-- TODO: Make this more robust by using jq or aeson.
replaceNeighboursWithProxy :: Array Port -> Int -> IO ()
replaceNeighboursWithProxy ports i =
    mapM_ (replaceNeighbourWithProxy ports i) [1..env_CARDANO_TESTNET_NUM_NODES]

replaceNeighbourWithProxy :: Array Port -> Int -> Int -> IO ()
replaceNeighbourWithProxy ports targetNodeIndex nbrIndex = do
    let prxy = show $ getProxyPort nbrIndex
        orig =
            maybe
                (error "replaceNeighbourWithProxy: Index out of bounds")
                show
                (Array.getIndex (nbrIndex - 1) ports)
    runCmd_ $ mconcat
      ["sed -i 's/", orig, "/", prxy, "/g' ", topologyFileS]
  where
    topologyFileS = topologyFile targetNodeIndex

replaceAllNeighboursWithProxy :: Array Port -> IO ()
replaceAllNeighboursWithProxy ports =
    mapM_ (replaceNeighboursWithProxy ports) [1..env_CARDANO_TESTNET_NUM_NODES]

toxiproxyCreate :: Array Port -> Int -> IO ()
toxiproxyCreate ports i =
    runCmd_ $ mconcat
      [ "toxiproxy-cli create --listen 127.0.0.1:", l
      , " --upstream 127.0.0.1:", u
      , " "
      , nodeName i
      ]
  where
    u = maybe (error "toxiproxyCreate: Unknown Port") show $ Array.getIndex (i - 1) ports
    l = show $ getProxyPort i

toxiproxyCreateClients :: Array Port -> IO ()
toxiproxyCreateClients ports =
    mapM_ (toxiproxyCreate ports) [1..env_CARDANO_TESTNET_NUM_NODES]

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



toxToggle :: Int -> IO ()
toxToggle i =
    runCmd_ $ "toxiproxy-cli toggle " <> nodeName i

toxLatency :: String -> NetworkDirection -> ToxLatencyOpts -> Int -> IO ()
toxLatency name ndir opts i =
    runCmd_ $ unwords
      [ "toxiproxy-cli toxic add -n"
      , name
      , "-t latency"
      , direction
      , attrs
      , nodeName i
      ]
  where
    latency = show (tloLatency opts)
    jitter = show (tloJitter opts)
    direction =
        case ndir of
            Upstream -> "-u"
            Downstream -> "-d"
    attrs = mconcat ["-a latency=", latency, " -a jitter=", jitter]

toxRemove :: String -> Int -> IO ()
toxRemove name i = do
    runCmd_ $ mconcat
      [ "toxiproxy-cli toxic remove -n ", name, " ", nodeName i]

addToxicity :: IO ()
addToxicity = do
    let allNodes = [1..env_CARDANO_TESTNET_NUM_NODES]
    mapM_ toxToggle allNodes

removeToxicity :: IO ()
removeToxicity = do
    let allNodes = [1..env_CARDANO_TESTNET_NUM_NODES]
    mapM_ toxToggle allNodes

--------------------------------------------------------------------------------
-- Telemetry
--------------------------------------------------------------------------------

getTipBlockNo :: FilePath -> IO (String, String, String)
getTipBlockNo socketPath = do
    res <-
        runCmd
            "cardano-cli query tip"
            [ optNetwork
            , opt "socket-path" socketPath
            ]
            & Cmd.pipeChunks "jq -r '.slot,.block,.hash'"
            & nonEmptyLines
            & Stream.fold Fold.toList
    case res of
        [s, b, h] -> pure (s, b, h)
        _ -> error "getTipBlockNo: Unable to parse block and hash."

data NodeTip = NodeTip
    { ntNodeIndex :: Int
    , ntBlockNo :: String
    , ntSlotNo :: String
    , ntBlockHash :: String
    }

getNodeTips :: IO [NodeTip]
getNodeTips = mapM getNodeTip [1..env_CARDANO_TESTNET_NUM_NODES]
  where
    getNodeTip i = do
        (s, b, h) <- getTipBlockNo (nodeSocketPath i)
        pure $ NodeTip i b s h

showNodeTip :: NodeTip -> String
showNodeTip (NodeTip {..}) =
    mconcat ["Node [", show ntNodeIndex, "] -> ", ntBlockNo, ", ", ntSlotNo, ", ", ntBlockHash]

renderNodeTips :: IO ()
renderNodeTips = do
    res <- getNodeTips
    putStrLn divider
    putStrLn $ unlines $ map showNodeTip res

runChairman :: IO ()
runChairman =
    runCmd
        (cardanoNodeChairman <> " run")
        ( [ opt "config" configurationYamlFile
          , opt "timeout" env_CHAIRMAN_TIMEOUT_SECONDS
          , opt "require-progress" env_CHAIRMAN_MIN_PROGRESS
          ]
            ++ [opt "socket-path" (nodeSocketPath i) | i <- [1 .. env_CARDANO_TESTNET_NUM_NODES]]
        )
        & Stream.fold Stdio.writeChunks

applyFaults :: [Scenario.FaultAction] -> IO ()
applyFaults = mapM_ applyFault
  where
    applyFault :: FaultAction -> IO ()
    applyFault (FaultIsolate nodes) = mapM_ toxToggle nodes
    applyFault (FaultLatency nodes direction latencyMs jitterMs) = mapM_ (applyLatencyToNode direction) nodes
      where
        opts = ToxLatencyOpts{tloLatency = latencyMs, tloJitter = jitterMs}
        applyLatencyToNode Scenario.Upstream i = toxLatency "scenario-latency-up" Upstream opts i
        applyLatencyToNode Scenario.Downstream i = toxLatency "scenario-latency-down" Downstream opts i
        applyLatencyToNode Scenario.Both i = do
            toxLatency "scenario-latency-up" Upstream opts i
            toxLatency "scenario-latency-down" Downstream opts i
