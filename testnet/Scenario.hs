{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Scenario (
  ScenarioConfig (..),
  Topology (..),
  NodeGroup (..),
  NodeRole (..),
  Executables (..),
  GenesisConfig (..),
  FaultAction (..),
  LatencyDirection (..),
  Observability (..),
  loadScenario,
  scenarioConfig,
  env_TESTNET_SCENARIO_DEFAULT,
) where

import Control.Monad (when)
import Data.Aeson (FromJSON (..), withObject, withText, (.!=), (.:), (.:?))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Yaml qualified as Yaml
import System.Environment (lookupEnv)
import System.IO.Unsafe (unsafePerformIO)

data NodeRole = Spo | Relay
  deriving (Show, Eq)

instance FromJSON NodeRole where
  parseJSON = withText "NodeRole" $ \case
    "spo" -> pure Spo
    "relay" -> pure Relay
    other -> fail $ "topology.groups[].role: unknown role " <> show other

data NodeGroup = NodeGroup
  { groupName :: Text
  , groupRole :: NodeRole
  , groupCount :: Int
  , groupStake :: Maybe Int
  }
  deriving (Show, Eq)

instance FromJSON NodeGroup where
  parseJSON = withObject "NodeGroup" $ \v ->
    NodeGroup
      <$> v .: "name"
      <*> v .: "role"
      <*> v .: "count"
      <*> v .:? "stake"

data Executables = Executables
  { execCardanoNode :: Maybe FilePath
  , execCardanoCli :: Maybe FilePath
  , execCardanoTestnet :: Maybe FilePath
  }
  deriving (Show, Eq)

instance FromJSON Executables where
  parseJSON = withObject "Executables" $ \v ->
    Executables
      <$> v .:? "cardano_node"
      <*> v .:? "cardano_cli"
      <*> v .:? "cardano_testnet"

data Topology = Topology
  { topologyMagic :: Int
  , topologyGroups :: [NodeGroup]
  , topologyExecutables :: Maybe Executables
  }
  deriving (Show, Eq)

instance FromJSON Topology where
  parseJSON = withObject "Topology" $ \v ->
    Topology
      <$> v .: "magic"
      <*> v .: "groups"
      <*> v .:? "executables"

data GenesisConfig = GenesisConfig
  { genesisEpochLengthSlots :: Int
  , genesisSlotLengthSeconds :: Double
  , genesisSecurityParamK :: Int
  , genesisActiveSlotCoeffF :: Double
  , genesisNumDReps :: Int
  , genesisMaxLovelaceSupply :: Integer
  , genesisStartDirectlyInDijkstra :: Bool
  }
  deriving (Show, Eq)

instance FromJSON GenesisConfig where
  parseJSON = withObject "GenesisConfig" $ \v ->
    GenesisConfig
      <$> v .: "epoch_length_slots"
      <*> v .: "slot_length_seconds"
      <*> v .: "security_param_k"
      <*> v .: "active_slot_coeff_f"
      <*> v .: "num_dreps"
      <*> v .: "max_lovelace_supply"
      <*> v .: "start_directly_in_dijkstra"

data LatencyDirection = Upstream | Downstream | Both
  deriving (Show, Eq)

instance FromJSON LatencyDirection where
  parseJSON = withText "LatencyDirection" $ \case
    "upstream" -> pure Upstream
    "downstream" -> pure Downstream
    "both" -> pure Both
    other -> fail $ "faults[].direction: unknown direction " <> show other

data FaultAction
  = FaultIsolate
    { faultNodes :: [Int]
    }
  | FaultLatency
    { faultNodes :: [Int]
    , faultDirection :: LatencyDirection
    , faultLatencyMs :: Int
    , faultJitterMs :: Int
    }
  -- TODO: we can support later:
  -- - crast/restart
  -- - protocol aware issues (?, message delay)
  -- - clock skew (?)
  -- - round/slot scheduled faults
  -- - etc
  deriving (Show, Eq)

instance FromJSON FaultAction where
  parseJSON = withObject "FaultAction" $ \v -> do
    faultType <- v .: "type" :: Parser Text
    case faultType of
      "isolate" ->
        FaultIsolate <$> v .: "nodes"
      "latency" ->
        FaultLatency
          <$> v .: "nodes"
          <*> v .:? "direction" .!= Both
          <*> v .: "latency_ms"
          <*> v .:? "jitter_ms" .!= 0
      other -> fail $ "faults[].type: unknown fault type " <> show other

newtype Observability = Observability
  { observabilityTraceFilters :: [Text]
  }
  deriving (Show, Eq)

instance FromJSON Observability where
  parseJSON = withObject "Observability" $ \v ->
      Observability <$> v .:? "trace_filters" .!= []

data ScenarioConfig = ScenarioConfig
  { scenarioConfigName :: Text
  , scenarioConfigDescription :: Maybe Text
  , scenarioConfigTopology :: Topology
  , scenarioConfigGenesis :: GenesisConfig
  , scenarioConfigFaults :: [FaultAction]
  , scenarioConfigObservability :: Observability
  }
  deriving (Show, Eq)

instance FromJSON ScenarioConfig where
  parseJSON = withObject "ScenarioConfig" $ \v -> do
    -- TODO: Support peras specific values
    when (KeyMap.member "peras" v) $
      fail
        "top-level \"peras\" section is not supported yet: PerasParams \
        \(ouroboros-consensus) are currently compiled-in defaults, not read from \
        \any config file."
    scenarioObj <- v .: "scenario"
    ScenarioConfig
      <$> scenarioObj .: "name"
      <*> scenarioObj .:? "description"
      <*> v .: "topology"
      <*> v .: "genesis"
      <*> v .:? "faults" .!= []
      <*> v .:? "observability" .!= Observability []

loadScenario :: FilePath -> IO ScenarioConfig
loadScenario path = do
  result <- Yaml.decodeFileEither path
  case result of
      Left err ->
        ioError . userError $
          "Failed to parse scenario file " <> path <> ":\n" <> Yaml.prettyPrintParseException err
      Right config -> pure config

env_TESTNET_SCENARIO_DEFAULT :: FilePath
env_TESTNET_SCENARIO_DEFAULT = "scenarios/vanilla.yaml"

{-# NOINLINE scenarioConfig #-}
scenarioConfig :: ScenarioConfig
scenarioConfig = unsafePerformIO $ do
  path <- fromMaybe env_TESTNET_SCENARIO_DEFAULT <$> lookupEnv "TESTNET_SCENARIO"
  loadScenario path
