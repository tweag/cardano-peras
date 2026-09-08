module Cooked where

import Cardano.Api
import Cooked.BlockChain
import Cooked.Effect
import Cooked.Skeleton
import Cooked.Utilities
import Data.Map qualified as Map
import Data.String
import Plutus.Script.Utils.Address qualified as Script

newtype NodeIndex = NodeIndex Int

newtype FaucetIndex = FaucetIndex Int

faucetSignatory :: FaucetIndex -> IO TxSkelSignatory
faucetSignatory (FaucetIndex i) =
  signatoryFromFile
    @GenesisUTxOKey
    $ "/home/monsieuro/tweag/cardano-peras/testnet/devnet-env/utxo-keys/utxo"
      <> show i
      <> "/utxo.skey"

nodeConfig :: NodeIndex -> LocalNodeConnectInfo
nodeConfig (NodeIndex i) =
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
fetchFrom (Script.toAddress -> wal) title = do
  define title wal
    >>= utxosAt
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

runInIO :: (Show a) => NodeIndex -> DirectBlockChain a -> IO ()
runInIO i = runBlockChainFromConfTemplate $ nodeConfig i
