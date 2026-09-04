{-# LANGUAGE OverloadedStrings #-}

module JsonFile (
  readJsonFile,
  writeJsonFile,
  lookupObj,
  setPath,
) where

import Data.Aeson (Value (..))
import Data.Aeson qualified as Aeson
import Data.Aeson.Encode.Pretty qualified as AesonPretty
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LBS
import Data.Text (Text)

readJsonFile :: FilePath -> IO Aeson.Object
readJsonFile path = do
  bytes <- LBS.readFile path
  case Aeson.eitherDecode bytes of
    Left err -> ioError . userError $ "readJsonFile: failed to parse " ++ path ++ ": " ++ err
    Right (Object obj) -> pure obj
    Right _ -> ioError . userError $ "readJsonFile: " ++ path ++ " is not a JSON object"

writeJsonFile :: FilePath -> Aeson.Object -> IO ()
writeJsonFile path obj = LBS.writeFile path (AesonPretty.encodePretty (Object obj))

lookupObj :: Text -> Aeson.Object -> Aeson.Object
lookupObj key obj =
  case KeyMap.lookup (Key.fromText key) obj of
    Just (Object o) -> o
    _ -> KeyMap.empty

-- @setPath ["a","b"] v obj@ sets @obj.a.b = v@.
setPath :: [Text] -> Value -> Aeson.Object -> Aeson.Object
setPath [] _ obj = obj
setPath [k] v obj = KeyMap.insert (Key.fromText k) v obj
setPath (k : ks) v obj =
  KeyMap.insert (Key.fromText k) (Object (setPath ks v (lookupObj k obj))) obj
