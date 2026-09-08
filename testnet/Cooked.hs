module Cooked where

import Cardano.Api
import Cooked.BlockChain
import Cooked.Effect
import Cooked.Pretty
import Cooked.Skeleton
import Cooked.Utilities
import Data.Map qualified as Map
import Data.String
import Plutus.Script.Utils.Address qualified as Script
import PlutusLedgerApi.V3 qualified as Api

faucetSignatory :: Int -> IO TxSkelSignatory
faucetSignatory i =
  signatoryFromFile
    @GenesisUTxOKey
    $ "/home/monsieuro/tweag/cardano-peras/testnet/devnet-env/utxo-keys/utxo"
      <> show i
      <> "/utxo.skey"

nodeConfig :: Int -> LocalNodeConnectInfo
nodeConfig i =
  LocalNodeConnectInfo
    { localConsensusModeParams = CardanoModeParams (EpochSlots 21600),
      localNodeNetworkId = Testnet (NetworkMagic 42),
      localNodeSocketPath =
        fromString $
          "/home/monsieuro/tweag/cardano-peras/testnet/devnet-env/socket/node"
            <> show i
            <> "/sock"
    }

fetchFrom :: (Script.ToAddress addr) => addr -> String -> DirectBlockChain ()
fetchFrom wal title = do
  define_ title $
    case Script.toAddress wal of
      Api.Address (Api.PubKeyCredential cred) _ -> toHash cred
      Api.Address (Api.ScriptCredential cred) _ -> toHash cred
  utxosAt wal
    >>= retrieveUtxos
    >>= retrieve Map.toList
    >>= retrieve (fmap snd)
    >>= noteL title

fetchAll :: DirectBlockChain ()
fetchAll =
  allUtxos
    >>= retrieveUtxos
    >>= retrieve Map.toList
    >>= retrieve (fmap snd)
    >>= noteL "All Utxos"

runInIO :: (Show a) => Int -> DirectBlockChain a -> IO ()
runInIO i = runBlockChainFromConfTemplate $ nodeConfig i
