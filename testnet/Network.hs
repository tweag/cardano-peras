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
    portsIO,
    NodeTip (..),
    renderNodeTips,
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Misc
import Streamly.Console.Stdio qualified as Stdio
import Data.Function ((&))
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream qualified as Stream
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.String (str)
import Streamly.Data.Array qualified as Array
import Streamly.Data.Array (Array)

--------------------------------------------------------------------------------
-- Toxicity
--------------------------------------------------------------------------------

portFile :: Int -> FilePath
portFile i =
    [str|#{env_TESTNET_WORK_DIR}/node-data/#{nodeDir}/port|]
  where
    nodeDir = "node" ++ show i

topologyFile :: Int -> FilePath
topologyFile i =
    [str|#{env_TESTNET_WORK_DIR}/node-data/#{nodeDir}/topology.json|]
  where
    nodeDir = "node" ++ show i

type Port = Int

getOriginalNodePort :: Int -> IO Port
getOriginalNodePort = fmap read . readFile . portFile

portsIO :: IO (Array Port)
portsIO = do
    ports <- mapM getOriginalNodePort [1..env_CARDANO_TESTNET_NUM_NODES]
    let portsStr = show ports
    putStrLn [str|Ports: #{portsStr}|]
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
    runCmd_ [str|sed -i 's/#{orig}/#{prxy}/g' #{topologyFileS}|]
  where
    topologyFileS = topologyFile targetNodeIndex

replaceAllNeighboursWithProxy :: Array Port -> IO ()
replaceAllNeighboursWithProxy ports =
    mapM_ (replaceNeighboursWithProxy ports) [1..env_CARDANO_TESTNET_NUM_NODES]

toxiproxyCreate :: Array Port -> Int -> IO ()
toxiproxyCreate ports i =
    runCmd_ [str|toxiproxy-cli create --listen 127.0.0.1:#{l} --upstream 127.0.0.1:#{u} #{n}|]
  where
    n = "node" ++ show i
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
    runCmd_ [str|toxiproxy-cli toggle #{proxyName}|]
  where
    proxyName = "node" ++ show i

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
    let allNodes = [1..env_CARDANO_TESTNET_NUM_NODES]
    mapM_ toxToggle allNodes

removeToxicity :: IO ()
removeToxicity = do
    let allNodes = [1..env_CARDANO_TESTNET_NUM_NODES]
    mapM_ toxToggle allNodes

--------------------------------------------------------------------------------
-- Telemetry
--------------------------------------------------------------------------------

socketFile :: Int -> FilePath
socketFile i = [str|#{env_TESTNET_WORK_DIR}/socket/#{nodeDir}/sock|]
  where
    nodeDir = "node" ++ show i

getTipBlockNo :: FilePath -> IO (String, String, String)
getTipBlockNo socketPath = do
    res <-
        runCmd
            "cardano-cli query tip"
            [ optNetwork
            , opt "socket-path" socketPath
            ]
            & Cmd.pipeChunks [str|jq -r '.slot,.block,.hash'|]
            & nonEmptyLines
            & Stream.fold Fold.toList
    case res of
        [s, b, h] -> pure (s, b, h)
        _ -> error [str|getTipBlockNo: Unable to parse block and hash.|]

data NodeTip = NodeTip
    { ntNodeName :: String
    , ntBlockNo :: String
    , ntSlotNo :: String
    , ntBlockHash :: String
    }

getNodeTips :: IO [NodeTip]
getNodeTips = mapM getNodeTip [1..env_CARDANO_TESTNET_NUM_NODES]
  where
    getNodeTip i = do
        (s, b, h) <- getTipBlockNo (socketFile i)
        let n = "node-" ++ show i
        pure $ NodeTip n b s h

showNodeTip :: NodeTip -> String
showNodeTip (NodeTip {..}) =
    [str|#{ntNodeName} -> #{ntBlockNo}, #{ntSlotNo}, #{ntBlockHash}|]

renderNodeTips :: IO ()
renderNodeTips = do
    res <- getNodeTips
    putStrLn divider
    putStrLn $ unlines $ map showNodeTip res
