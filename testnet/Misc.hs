{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Misc (
    -- Cli
    CmdStmt,
    CmdOption,
    flg,
    opt,
    raw,
    -- Exec paths
    cardanoCli,
    cardanoNode,
    cardanoTestnet,
    -- Common Opts
    optNetwork,
    optNodeSocket,
    optNode1Socket,
    optNode2Socket,
    optAnchorUrl,
    optAnchorDataHash,
    -- Utils
    printStep,
    runCmd_,
    runCmd,
    runCmd',
    drain,
    nonEmptyLines,
    divider,
    firstNonEmptyLine,
    printVar,
    ensureBlankWorkDir,
    hexify,
    -- Cardano Cli
    govVoteCreate,
    govQueryPrevHardforkActionTxId,
    govActionHarkFork,
    getPolicyId,
    getProtocolMajorVersion,
    getAddress,
    getScriptAddress,
    buildTransaction,
    signTransaction,
    submitTransaction,
    buildStakeAddress,
    genRegCertStakeAddress,
    genDeregCertStakeAddress,
    getTransactionId,
    getFirstUtxoAt,
    getUtxoListAt,
    nullUtxo,
    keygen,
    Wallet (..),
    mkWallet,
    walletKeyHash,
    fetchWallet,
    waitTill,
    waitTillExists,
    fstOutput,
    transferAda,
    -- Globals
    env_LOCAL_CONFIG_DIR,
    env_PLUTUS_SCRIPTS_DIR,
    env_POPULATE_WORK_DIR,
    env_TESTNET_WORK_DIR,
    env_CARDANO_TESTNET_MAGIC,
    env_CARDANO_TESTNET_NUM_NODES,
    env_CARDANO_TESTNET_NUM_SPO_NODES,
    env_CARDANO_TESTNET_NUM_RELAY_NODES,
    env_FAUCET_WALLET_VKEY_FILE,
    env_FAUCET_WALLET_SKEY_FILE,
    env_FAUCET_WALLET_ADDR,
    env_FAUCET_WALLET,
    env_TX_UNSIGNED,
    env_TX_SIGNED,
) where

-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

import Control.Concurrent (threadDelay)
import Data.Function ((&))
import Data.Word (Word8)
import Streamly.Data.Array (Array)
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream (Stream)
import Streamly.Data.Stream qualified as Stream
import Streamly.System.Command qualified as Cmd
import Streamly.Unicode.Stream qualified as Unicode
import Streamly.Unicode.String (str)
import System.FilePath ((<.>), (</>))
import System.Environment (lookupEnv)
import System.IO.Unsafe (unsafePerformIO)

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

waitTill :: String -> IO Bool -> IO ()
waitTill tag action =
    Stream.repeatM (printStep [str|Waiting: #{tag}|] >> threadDelay 3000000 >> action)
        & Stream.takeWhile (not . id)
        & Stream.fold Fold.drain

waitTillExists :: String -> IO ()
waitTillExists = waitTill "Utxo exists" . fmap not . nullUtxo

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
env_CARDANO_TESTNET_NUM_NODES = 5

env_CARDANO_TESTNET_NUM_SPO_NODES :: Int
env_CARDANO_TESTNET_NUM_SPO_NODES = 3

env_CARDANO_TESTNET_NUM_RELAY_NODES :: Int
env_CARDANO_TESTNET_NUM_RELAY_NODES = env_CARDANO_TESTNET_NUM_NODES - env_CARDANO_TESTNET_NUM_SPO_NODES

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
-- CmdStmt
-------------------------------------------------------------------------------

type CmdStmt = String

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

nodeSocketPath :: Int -> FilePath
nodeSocketPath i = env_TESTNET_WORK_DIR </> [str|socket/node#{iStr}/sock|]
    where iStr = show i

optAnchorUrl :: CmdOption
optAnchorUrl =
    opt
        "anchor-url"
        ("https://raw.githubusercontent.com/cardano-foundation/CIPs/b491a839708eb0296597008e7b6b093eda5e3363/CIP-0001/README.md" :: String)

optAnchorDataHash :: CmdOption
optAnchorDataHash =
    opt
        "anchor-data-hash"
        ("3a8aaa2aa27230b35b27b8b11a360ecc5df6871df40bb4d0b5a51f3aefe5386b" :: String)

optNetwork :: CmdOption
optNetwork = opt "testnet-magic" env_CARDANO_TESTNET_MAGIC

optNodeSocket :: Int -> CmdOption
optNodeSocket i = opt "socket-path" (nodeSocketPath i)

optNode1Socket :: CmdOption
optNode1Socket = optNodeSocket 1

optNode2Socket :: CmdOption
optNode2Socket = optNodeSocket 2

runCmd' :: String -> Stream IO (Array Word8)
runCmd' cmd = Stream.before (putStrLn [str|> #{cmd}|]) (Cmd.toChunks cmd)

runCmd_ :: String -> IO ()
runCmd_ cmd = do
    putStrLn [str|> #{cmd}|]
    Cmd.toStdout cmd

runCmd :: CmdStmt -> [CmdOption] -> Stream IO (Array Word8)
runCmd cmd args = runCmd' cmdStr
  where
    cmdOptStr (CoOpt k v) = [str|--#{k} #{v}|]
    cmdOptStr (CoFlg k) = [str|--#{k}|]
    cmdOptStr (CoRaw v) = v

    cmdList = cmd : map cmdOptStr args
    cmdStr = unwords cmdList

{-# NOINLINE cardanoCli #-}
cardanoCli :: FilePath
cardanoCli =
    maybe "cardano-cli" id $ unsafePerformIO (lookupEnv "CARDANO_CLI")

{-# NOINLINE cardanoNode #-}
cardanoNode :: FilePath
cardanoNode =
    maybe "cardano-node" id $ unsafePerformIO (lookupEnv "CARDANO_NODE")

{-# NOINLINE cardanoTestnet #-}
cardanoTestnet :: FilePath
cardanoTestnet =
    maybe "cardano-testnet" id $ unsafePerformIO (lookupEnv "CARDANO_TESTNET")

getProtocolMajorVersion :: IO Int
getProtocolMajorVersion =
    runCmd
        [str|#{cardanoCli} conway query protocol-parameters|]
        [optNetwork, optNode2Socket]
        & Cmd.pipeChunks [str|jq -r ".protocolVersion.major"|]
        & firstNonEmptyLine "getProtocolMajorVersion"
        & fmap read

getPolicyId :: FilePath -> IO String
getPolicyId scriptFile =
    runCmd
        [str|#{cardanoCli} conway transaction policyid|]
        [opt "script-file" scriptFile]
        & firstNonEmptyLine "getPolicyId"

getAddress :: FilePath -> IO String
getAddress vkeyFile =
    runCmd
        [str|#{cardanoCli} conway address build|]
        [ optNetwork
        , opt "payment-verification-key-file" vkeyFile
        ]
        & firstNonEmptyLine "getAddress"

getScriptAddress :: FilePath -> IO String
getScriptAddress scriptFile =
    runCmd
        [str|#{cardanoCli} conway address build|]
        [ optNetwork
        , opt "payment-script-file" scriptFile
        ]
        & firstNonEmptyLine "getScriptAddress"

govQueryPrevHardforkActionTxId :: IO (Maybe String)
govQueryPrevHardforkActionTxId = do
    runCmd
        [str|#{cardanoCli} conway query gov-state|]
        [ optNetwork
        , optNodeSocket 2
        ]
        & Cmd.pipeChunks [str|jq -r ".nextRatifyState.nextEnactState.prevGovActionIds.HardFork.txId"|]
        & firstNonEmptyLine "govQueryPrevHardforkAction"
        & fmap toMaybe
  where
    toMaybe "null" = Nothing
    toMaybe x = Just x

govVoteCreate :: [CmdOption] -> IO ()
govVoteCreate args =
    runCmd
        [str|#{cardanoCli} conway governance vote create|]
        args
        & drain

govActionHarkFork :: [CmdOption] -> IO ()
govActionHarkFork args =
    runCmd
        [str|#{cardanoCli} conway governance action create-hardfork|]
        (flg "testnet" : args)
        & drain

buildTransaction :: [CmdOption] -> IO ()
buildTransaction args =
    runCmd
        [str|#{cardanoCli} conway transaction build|]
        (optNetwork : optNode2Socket : args)
        & drain

signTransaction :: [CmdOption] -> IO ()
signTransaction args =
    runCmd
        [str|#{cardanoCli} conway transaction sign|]
        (optNetwork : args)
        & drain

submitTransaction :: [CmdOption] -> IO ()
submitTransaction args =
    runCmd
        [str|#{cardanoCli} conway transaction submit|]
        (optNetwork : optNode2Socket : args)
        & drain

buildStakeAddress :: [CmdOption] -> IO ()
buildStakeAddress args =
    runCmd
        [str|#{cardanoCli} conway stake-address build|]
        (optNetwork : args)
        & drain

genRegCertStakeAddress :: [CmdOption] -> IO ()
genRegCertStakeAddress args =
    runCmd
        [str|#{cardanoCli} conway stake-address registration-certificate|]
        args
        & drain

genDeregCertStakeAddress :: [CmdOption] -> IO ()
genDeregCertStakeAddress args =
    runCmd
        [str|#{cardanoCli} conway stake-address deregistration-certificate|]
        args
        & drain

getTransactionId :: String -> IO String
getTransactionId txSigned =
    runCmd
        [str|#{cardanoCli} conway transaction txid|]
        [ opt "tx-body-file" txSigned
        ]
        & Cmd.pipeChunks [str|jq -r ".txhash"|]
        & firstNonEmptyLine "getTransactionId"

getFirstUtxoAt :: String -> IO String
getFirstUtxoAt walletAddr =
    runCmd
        [str|#{cardanoCli} conway query utxo|]
        [ optNetwork
        , optNode2Socket
        , opt "address" walletAddr
        ]
        & Cmd.pipeChunks [str|jq -r "keys[0]"|]
        & firstNonEmptyLine "getFirstUtxoAt"

getUtxoListAt :: String -> IO [String]
getUtxoListAt walletAddr =
    runCmd
        [str|#{cardanoCli} conway query utxo|]
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
        [str|#{cardanoCli} latest query utxo|]
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
        [str|#{cardanoCli} address key-gen|]
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
        [str|#{cardanoCli} address key-hash|]
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
