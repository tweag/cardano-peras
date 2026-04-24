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
    -- Common Opts
    optNetwork,
    optNode1Socket,
    optNode2Socket,
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
    getPolicyId,
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

waitTillExists :: String -> IO ()
waitTillExists utxo =
    Stream.repeatM (printStep "Waiting" >> threadDelay 3000000 >> nullUtxo utxo)
        & Stream.takeWhile id
        & Stream.fold Fold.drain

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
env_CARDANO_TESTNET_NUM_NODES = 12

env_NODE1_SOCKET :: FilePath
env_NODE1_SOCKET = env_TESTNET_WORK_DIR </> "socket/node1/sock"

env_NODE2_SOCKET :: FilePath
env_NODE2_SOCKET = env_TESTNET_WORK_DIR </> "socket/node2/sock"

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

optNetwork :: CmdOption
optNetwork = opt "testnet-magic" env_CARDANO_TESTNET_MAGIC

optNode1Socket :: CmdOption
optNode1Socket = opt "socket-path" env_NODE1_SOCKET

optNode2Socket :: CmdOption
optNode2Socket = opt "socket-path" env_NODE2_SOCKET

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

getPolicyId :: FilePath -> IO String
getPolicyId scriptFile =
    runCmd
        "cardano-cli conway transaction policyid"
        [opt "script-file" scriptFile]
        & firstNonEmptyLine "getPolicyId"

getAddress :: FilePath -> IO String
getAddress vkeyFile =
    runCmd
        "cardano-cli conway address build"
        [ optNetwork
        , opt "payment-verification-key-file" vkeyFile
        ]
        & firstNonEmptyLine "getAddress"

getScriptAddress :: FilePath -> IO String
getScriptAddress scriptFile =
    runCmd
        "cardano-cli conway address build"
        [ optNetwork
        , opt "payment-script-file" scriptFile
        ]
        & firstNonEmptyLine "getScriptAddress"

buildTransaction :: [CmdOption] -> IO ()
buildTransaction args =
    runCmd
        "cardano-cli conway transaction build"
        (optNetwork : optNode2Socket : args)
        & drain

signTransaction :: [CmdOption] -> IO ()
signTransaction args =
    runCmd
        "cardano-cli conway transaction sign"
        (optNetwork : args)
        & drain

submitTransaction :: [CmdOption] -> IO ()
submitTransaction args =
    runCmd
        "cardano-cli conway transaction submit"
        (optNetwork : optNode2Socket : args)
        & drain

buildStakeAddress :: [CmdOption] -> IO ()
buildStakeAddress args =
    runCmd
        "cardano-cli conway stake-address build"
        (optNetwork : args)
        & drain

genRegCertStakeAddress :: [CmdOption] -> IO ()
genRegCertStakeAddress args =
    runCmd "cardano-cli conway stake-address registration-certificate" args
        & drain

genDeregCertStakeAddress :: [CmdOption] -> IO ()
genDeregCertStakeAddress args =
    runCmd "cardano-cli conway stake-address deregistration-certificate" args
        & drain

getTransactionId :: String -> IO String
getTransactionId txSigned =
    runCmd
        "cardano-cli conway transaction txid"
        [ opt "tx-body-file" txSigned
        ]
        & Cmd.pipeChunks [str|jq -r ".txhash"|]
        & firstNonEmptyLine "getTransactionId"

getFirstUtxoAt :: String -> IO String
getFirstUtxoAt walletAddr =
    runCmd
        "cardano-cli conway query utxo"
        [ optNetwork
        , optNode2Socket
        , opt "address" walletAddr
        ]
        & Cmd.pipeChunks [str|jq -r "keys[0]"|]
        & firstNonEmptyLine "getFirstUtxoAt"

getUtxoListAt :: String -> IO [String]
getUtxoListAt walletAddr =
    runCmd
        "cardano-cli conway query utxo"
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
        "cardano-cli latest query utxo"
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
        "cardano-cli address key-gen"
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
        "cardano-cli address key-hash"
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
