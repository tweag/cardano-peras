{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Network (
    replaceAllNeighboursWithProxy,
    toxiproxyServer,
    toxiproxyCreateClients,
    getNodeTips,
    addToxicity,
    removeToxicity,
    portsIO,
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
    Stream.zipWith (,) (Stream.enumerateFrom 1) (Array.read ports)
        & Stream.fold (Fold.drainMapM mappingFunc)
  where
    topologyFileS = topologyFile i
    mappingFunc (ni, orig0) = do
        let prxy = show $ getProxyPort ni
            orig = show orig0
        runCmd_ [str|sed -i 's/#{orig}/#{prxy}/g' #{topologyFileS}|]

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
            & Cmd.pipeChunks [str|jq -r '.slot,.block,.hash'|]
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
