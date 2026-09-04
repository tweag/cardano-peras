{-# LANGUAGE OverloadedStrings #-}

module Stake (
  redistributeStake,
) where

import Control.Monad (forM, unless)
import Data.Aeson (Object, Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Text qualified as Text

import JsonFile
import Misc
import Scenario

-- cardano-cli's `genesis create-testnet-data` writes the pre-genesis,
-- we edit this file under a Peras-fork-specific `extraConfig` section
-- of shelley-genesis.json:
--   extraConfig.initialFunds.data     :: base-address-hex -> lovelace
--   extraConfig.stakeCredentials.data :: stake-cred-hash-hex -> pool-id-hex
--   extraConfig.stakePools.data       :: pool-id-hex -> pool params
--
-- A base address's raw bytes are header(1) ++ paymentCredHash(28) ++
-- stakeCredHash(28), so the last 56 hex chars of an initialFunds key are the
-- stake credential hash to look up in stakeCredentials.data. Addresses with
-- no stake part (e.g. the plain utxo-keys faucet wallets) are 58 hex chars
-- total and simply won't match anything there.

extraConfigData :: Text -> Object -> KeyMap Value
extraConfigData section genesis =
  lookupObj "data" $ lookupObj section $ lookupObj "extraConfig" genesis

asText :: Value -> Maybe Text
asText (String t) = Just t
asText _ = Nothing

asInteger :: Value -> Maybe Integer
asInteger (Number n) = Just (round n)
asInteger _ = Nothing

-- | initialFunds keys (base addresses) whose embedded stake credential is
-- delegated, per stakeCredentials.data, to the given pool.
addressesForPool :: KeyMap Value -> KeyMap Value -> Text -> [Text]
addressesForPool stakeCredToPool initialFunds poolId =
  [ addr
  | key <- KeyMap.keys initialFunds
  , let addr = Key.toText key
  , Text.length addr == 114 -- base address: 1 + 28 + 28 bytes, hex-encoded
  , let stakeCredHash = Text.takeEnd 56 addr
  , Just credPoolId <- [KeyMap.lookup (Key.fromText stakeCredHash) stakeCredToPool >>= asText]
  , credPoolId == poolId
  ]

data PoolStakeInfo = PoolStakeInfo
  { psiNodeIndex :: Int
  , psiAddresses :: [Text]
  }

collectPoolStakeInfo :: KeyMap Value -> KeyMap Value -> [Int] -> IO [PoolStakeInfo]
collectPoolStakeInfo stakeCredToPool initialFunds =
  mapM $ \i -> do
    poolId <- Text.pack <$> getPoolId (poolColdVkeyFile i)
    pure PoolStakeInfo{psiNodeIndex = i, psiAddresses = addressesForPool stakeCredToPool initialFunds poolId}

-- | Redistribute the baseline (evenly-split, genesis-time) stake among the
-- pools of any SPO group that specifies a `stake`.
redistributeStake :: IO ()
redistributeStake = do
  let
    weightedGroups =
      [ (g, w, idxs)
      | (g, idxs) <- env_SPO_GROUP_POOL_INDICES
      , Just w <- [groupStake g]
      ]
  unless (null weightedGroups) $ do
    genesis <- readJsonFile shelleyGenesisFile
    let
      stakeCredToPool = extraConfigData "stakeCredentials" genesis
      initialFunds = extraConfigData "initialFunds" genesis

    groupsInfo <- forM weightedGroups $ \(g, weight, idxs) -> do
      pools <- collectPoolStakeInfo stakeCredToPool initialFunds idxs
      pure (g, weight, pools)

    let
      emptyPools =
        [ (groupName g, psiNodeIndex p)
        | (g, _, pools) <- groupsInfo
        , p <- pools
        , null (psiAddresses p)
        ]
    unless (null emptyPools) $
      ioError . userError $
        "redistributeStake: no delegator credentials found for pool(s) "
          ++ show emptyPools
          ++ ". cardano-testnet only creates max(3, genesis.num_dreps) stake-delegator "
          ++ "credentials, spread evenly across pools -- raise genesis.num_dreps to at "
          ++ "least the total SPO pool count so every weighted pool gets at least one "
          ++ "to rebalance."

    let
      currentAmount addr = maybe 0 id (KeyMap.lookup (Key.fromText addr) initialFunds >>= asInteger)
      allAddrs = [a | (_, _, pools) <- groupsInfo, p <- pools, a <- psiAddresses p]
      totalLovelace = sum (map currentAmount allAddrs)
      totalWeight = sum [w | (_, w, _) <- groupsInfo]

      updates =
        [ (a, perAddr)
        | (_, weight, pools) <- groupsInfo
        , let groupTotal = totalLovelace * toInteger weight `div` toInteger totalWeight
              perPool = groupTotal `div` toInteger (length pools)
        , p <- pools
        , let perAddr = perPool `div` toInteger (length (psiAddresses p))
        , a <- psiAddresses p
        ]

      initialFunds' = foldr (\(a, amt) m -> KeyMap.insert (Key.fromText a) (Number (fromInteger amt)) m) initialFunds updates

    writeJsonFile shelleyGenesisFile (setPath ["extraConfig", "initialFunds", "data"] (Object initialFunds') genesis)
