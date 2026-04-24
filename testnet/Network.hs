{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Network (
    replaceAllNeighboursWithProxy,
    toxiproxyServer,
    toxiproxyCreateClients,
    savePortAndProxyMappings,
    getNodeTips,
    addToxicity,
    removeToxicity,
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Misc
import Streamly.Console.Stdio qualified as Stdio
import Data.Function ((&))
import Data.List ((\\))
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream qualified as Stream
import Streamly.FileSystem.FileIO qualified as File
import Streamly.FileSystem.Path qualified as Path
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.String (str)
import System.FilePath ((</>))
import Data.Map qualified as Map
import Data.IntMap qualified as IntMap
import Data.Map (Map)
import Data.IntMap (IntMap)

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

savePortAndProxyMappings :: IO ()
savePortAndProxyMappings = do
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
