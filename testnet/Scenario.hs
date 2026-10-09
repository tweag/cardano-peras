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
  PrometheusConfig (..),
  loadScenario,
  scenarioConfig,
  env_TESTNET_SCENARIO_DEFAULT,
) where

import Control.Monad (when)
import Data.Aeson (FromJSON (..), Value (..), withObject, withText, (.!=), (.:), (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser)
import Data.Bool (bool)
import Data.IP (IP)
import Data.Map (Map)
import Data.Map qualified as Map
import Data.Maybe (fromMaybe)
import Data.Scientific (floatingOrInteger)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Yaml qualified as Yaml
import Text.Read (readMaybe)
import System.Environment (lookupEnv)
import System.IO.Unsafe (unsafePerformIO)
import System.FilePath ((</>))

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

data PrometheusConfig = PrometheusConfig
  { prometheusListenIP :: IP
  , prometheusListenPort :: Maybe Int
  }
  deriving (Show, Eq)

instance FromJSON PrometheusConfig where
  parseJSON = withObject "PrometheusConfig" $ \v -> do
    mIpText <- v .:? "ip" :: Parser (Maybe Text)
    listenIP <- case mIpText of
      Nothing -> pure (read "127.0.0.1")
      Just ipText -> case readMaybe (T.unpack ipText) of
        Just ip -> pure ip
        Nothing -> fail $ "prometheus.ip: invalid IP address " <> show ipText
    PrometheusConfig listenIP <$> v .:? "port"

data ScenarioConfig = ScenarioConfig
  { scenarioConfigName :: Text
  , scenarioConfigDescription :: Maybe Text
  , scenarioConfigTopology :: Topology
  , scenarioConfigGenesis :: GenesisConfig
  , scenarioConfigFaults :: [FaultAction]
  , scenarioConfigObservability :: Observability
  , scenarioConfigPrometheus :: PrometheusConfig
  , scenarioConfigEnvironment :: Map String String
  }
  deriving (Show, Eq)

-- | Parse a flat YAML dict into a 'Map String String', coercing scalar
-- values (bools, numbers) to their string representation. Fails on nested
-- objects or arrays.
parseEnvironment :: Value -> Parser (Map String String)
parseEnvironment = withObject "environment" $
  fmap Map.fromList . traverse (uncurry yamlToScalar) . KeyMap.toList
 where
  yamlToScalar :: KeyMap.Key -> Value -> Parser (String, String)
  yamlToScalar k val = do
    s <- case val of
      String t -> pure $ T.unpack t
      Bool b   -> pure $ bool "0" "1" b
      Number n -> pure $ either show show $ floatingOrInteger @Double @Integer n
      Null     -> pure ""
      _        -> fail $ "env." <> show k <> ": expected a scalar (string, number or bool)"
    pure (Key.toString k, s)

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
      <*> v .:? "prometheus" .!= PrometheusConfig (read "127.0.0.1") Nothing
      <*> maybe (pure mempty) parseEnvironment (KeyMap.lookup "env" v)

loadScenario :: FilePath -> IO ScenarioConfig
loadScenario path = do
  result <- Yaml.decodeFileEither $ "testnet" </> path
  case result of
      Left _ -> do
        result2 <- Yaml.decodeFileEither path
        case result2 of
          Left err ->
            ioError . userError $
              "Failed to parse scenario file " <> path <> ":\n" <> Yaml.prettyPrintParseException err
          Right config -> pure config
      Right config -> pure config

env_TESTNET_SCENARIO_DEFAULT :: FilePath
env_TESTNET_SCENARIO_DEFAULT = "scenarios/vanilla.yaml"

{-# NOINLINE scenarioConfig #-}
scenarioConfig :: ScenarioConfig
scenarioConfig = unsafePerformIO $ do
  path <- fromMaybe env_TESTNET_SCENARIO_DEFAULT <$> lookupEnv "TESTNET_SCENARIO"
  loadScenario path
