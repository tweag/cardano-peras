{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module UI where

import Control.Concurrent (forkIO, threadDelay)
import Control.Exception (finally)
import Control.Monad (forever, void)
import Control.Monad.IO.Class (MonadIO (..))
import Control.Monad.State.Class (MonadState)
import Data.ByteString.Char8 qualified as BC
import Data.Char (digitToInt, isDigit)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.List (intersperse)
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import System.Directory (removeFile)
import System.IO (IOMode (WriteMode), hClose, hFlush, openFile, stderr, stdout)
import Text.Read (readMaybe)

import Brick
import Brick.BChan (newBChan, writeBChan)
import Brick.Widgets.Border as B
import Brick.Widgets.Center as C
import Data.Vector qualified as V
import Graphics.Vty qualified as V
import Graphics.Vty.Platform.Unix (mkVty)

import Network
import UI.CommServer

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

data UiEvent = ReadFromDatabase

data ColumnSpec a = ColumnSpec
    { colHeader :: String
    , colWidth :: Int
    , colRender :: a -> Widget ()
    }

brickTable :: [ColumnSpec a] -> [Widget ()] -> [a] -> Widget ()
brickTable cols emptyFallback rows =
    if null rows
        then vBox emptyFallback
        else vBox (headerRow : hBorder : bodyRows)
  where
    pipe = str " | "
    headerRow = hBox $ intersperse pipe $ map drawHeaderCell cols
    drawHeaderCell col = hLimit (colWidth col) (padRight Max (str (colHeader col)))
    bodyRows = map drawRow rows
    drawRow item = hBox $ intersperse pipe $ map (`drawBodyCell` item) cols
    drawBodyCell col item = hLimit (colWidth col) (padRight Max (colRender col item))

data Property = Property
    { propLabel :: String
    , propValue :: Widget ()
    }

propertyPanel :: [Property] -> Widget ()
propertyPanel properties = vBox $ map drawRow properties
  where
    maxLabelWidth = maximum (0 : map (length . propLabel) properties)
    drawRow prop =
        let labelStr = propLabel prop ++ ":"
            labelWidget = hLimit (maxLabelWidth + 2) (padRight Max (str labelStr))
         in labelWidget <+> propValue prop

--------------------------------------------------------------------------------
-- Low-Level Output Capture Engine
--------------------------------------------------------------------------------

captureExternalOutputs :: IO a -> IO (a, [String])
captureExternalOutputs action = do
    let tempPath = "temp_capture.log"
    savedStdout <- hDuplicate stdout
    savedStderr <- hDuplicate stderr
    logFileHandle <- openFile tempPath WriteMode
    hDuplicateTo logFileHandle stdout
    hDuplicateTo logFileHandle stderr
    hClose logFileHandle

    let restoreHandles = do
            hFlush stdout
            hFlush stderr
            hDuplicateTo savedStdout stdout
            hDuplicateTo savedStderr stderr
            hClose savedStdout
            hClose savedStderr

    result <- action `finally` restoreHandles
    capturedBytes <- BC.readFile tempPath
    removeFile tempPath
    return (result, map BC.unpack (BC.lines capturedBytes))

--------------------------------------------------------------------------------
-- TUI State Engine
--------------------------------------------------------------------------------

data UiState = UiState
    { inputSlot :: String
    , inputHash :: String
    , fetchedTips :: [NodeTip]
    , uiLogs :: [String]
    , isSystemLocked :: Bool
    , partitionActive :: Bool
    , database :: Database
    }

initialState :: UiState
initialState =
    UiState
        { inputSlot = ""
        , inputHash = ""
        , fetchedTips = []
        , uiLogs = ["Console initialized. Actions available."]
        , isSystemLocked = False
        , partitionActive = False
        , database = initialDB
        }

--------------------------------------------------------------------------------
-- View Layer (UI Layout)
--------------------------------------------------------------------------------

voteForm :: UiState -> Widget ()
voteForm st =
    B.borderWithLabel (str " Vote Form & Status ") $
        padAll 1 $
            propertyPanel
                [ Property "Slot Number" $
                    let text = if null (inputSlot st) then "<empty>" else inputSlot st
                     in withAttr inputAttr (str text)
                , Property "Block Hash" $
                    let text = if null (inputHash st) then "<empty>" else inputHash st
                     in withAttr inputAttr (str text)
                , Property "Partition Status" $
                    if partitionActive st
                        then withAttr partitionOnAttr (str "ACTIVE")
                        else withAttr partitionOffAttr (str "INACTIVE")
                ]

logsDisplay :: UiState -> Widget ()
logsDisplay st =
    B.borderWithLabel (str " Logs ") $
        let visibleLogs = take 4 (uiLogs st)
         in if null visibleLogs
                then str " "
                else vBox (map (withAttr logTextAttr . str) visibleLogs)

databaseTableDisplay :: UiState -> Widget ()
databaseTableDisplay st =
    B.borderWithLabel (str " Per-Node Database Registry ")
        . padTopBottom 1
        . padLeftRight 2
        . brickTable columnConfig fallback
        . fmap (fmap pnLatestAdvert)
        $ zip ([1 ..] :: [Int]) (V.toList (database st))
  where
    fallback = [str "No registered node data found in shared memory."]

    columnConfig =
        [ ColumnSpec "Node Index" 12 (\(idx, _) -> str ("Node [" ++ show idx ++ "]"))
        , ColumnSpec "Slot" 6 (\(_, info) -> withAttr logTextAttr (str (show (pnSlotNo info))))
        , ColumnSpec "Block No" 6 (\(_, info) -> withAttr logTextAttr (str (show (pnBlockNo info))))
        , ColumnSpec "Block Hash" 12 (\(_, info) -> withAttr logTextAttr (str (pnBlockHash info)))
        , ColumnSpec "Votes Count" 6 (\(_, info) -> withAttr inputAttr (str (show (pnNumVotes info))))
        , ColumnSpec "Certs Count" 6 (\(_, info) -> withAttr inputAttr (str (show (pnNumCerts info))))
        , ColumnSpec
            "Chain Weight"
            12
            ( \(_, info) ->
                let weightPartStr = show (pnChainLen info) ++ " + " ++ show (pnPerasBoost info)
                 in withAttr inputAttr (str weightPartStr)
            )
        ]

drawUi :: UiState -> [Widget ()]
drawUi st =
    [ C.center $
        B.borderWithLabel (str " Node Tip Monitor ") $
            vBox
                [ drawStatusBanner (isSystemLocked st)
                , padAll 1 $ voteForm st
                , padLeftRight 1 $ databaseTableDisplay st
                , padLeftRight 1 $ logsDisplay st
                , hBorder
                , padAll 1 $ drawActionInstructions (isSystemLocked st)
                ]
    ]

drawStatusBanner :: Bool -> Widget ()
drawStatusBanner False =
    withAttr successAttr $ C.hCenter $ str " [SYSTEM IDLE] "
drawStatusBanner True =
    withAttr loadingAttr $ C.hCenter $ str $ " [LOCKED] "

drawActionInstructions :: Bool -> Widget ()
drawActionInstructions False =
    str "[1-9]: Populate Vote Synthesis Form | [s]: Synthesize Vote | [p]: Toggle Partition | [esc]: Exit"
drawActionInstructions True =
    withAttr warningAttr $ str "Control locked until votes are processed"

--------------------------------------------------------------------------------
-- Styling / Attributes
--------------------------------------------------------------------------------

inputAttr, nodeNameAttr, logTextAttr, successAttr, loadingAttr, warningAttr, partitionOnAttr, partitionOffAttr :: AttrName
inputAttr = attrName "input"
nodeNameAttr = attrName "nodeName"
logTextAttr = attrName "logText"
successAttr = attrName "success"
loadingAttr = attrName "loading"
warningAttr = attrName "warning"
partitionOnAttr = attrName "partitionOn"
partitionOffAttr = attrName "partitionOff"

uiStyles :: AttrMap
uiStyles =
    attrMap
        V.defAttr
        [ (inputAttr, V.defAttr `V.withForeColor` V.cyan `V.withStyle` V.bold)
        , (nodeNameAttr, V.defAttr `V.withForeColor` V.yellow)
        , (logTextAttr, V.defAttr `V.withForeColor` V.green)
        , (successAttr, V.black `on` V.green)
        , (loadingAttr, V.black `on` V.yellow)
        , (warningAttr, V.defAttr `V.withForeColor` V.red `V.withStyle` V.bold)
        , (partitionOnAttr, V.black `on` V.cyan)
        , (partitionOffAttr, V.defAttr `V.withForeColor` V.white `V.withStyle` V.dim)
        ]

--------------------------------------------------------------------------------
-- Controller Layer (Keyboard Guard Router)
--------------------------------------------------------------------------------

withUnlockedState :: (MonadState UiState m) => (UiState -> m ()) -> m ()
withUnlockedState next = do
    st <- get
    case isSystemLocked st of
        True -> modify $ \s -> s{uiLogs = "Command Rejected: Locked while memory populated." : uiLogs s}
        False -> next st

handlePartitionEvent :: EventM () UiState ()
handlePartitionEvent =
    withUnlockedState $ \st ->
        if partitionActive st
            then do
                ((), interceptedLogs) <- liftIO $ captureExternalOutputs removeToxicity
                modify $ \s ->
                    s
                        { partitionActive = False
                        , uiLogs = interceptedLogs ++ ["Partition removed."] ++ uiLogs s
                        }
            else do
                ((), interceptedLogs) <- liftIO $ captureExternalOutputs addToxicity
                modify $ \s ->
                    s
                        { partitionActive = True
                        , uiLogs = interceptedLogs ++ ["Partition created."] ++ uiLogs s
                        }

handleVoteSynthesisEvent ::
    ( MonadState UiState m
    , MonadIO m
    ) =>
    IORef Database -> m ()
handleVoteSynthesisEvent dbRef = withUnlockedState $ \st -> do
    case (readMaybe (inputSlot st) :: Maybe Int, inputHash st) of
        (Just s, h) | not (null h) -> do
            liftIO $ atomicModifyIORef' dbRef ((,()) . addVoteCreateRequestToAllNodes (s, h))
            modify $ \s' ->
                s'
                    { isSystemLocked = True
                    , uiLogs = "Synthesizing Vote. Controls locked." : uiLogs s'
                    }
        _ ->
            modify $ \s' -> s'{uiLogs = "Error: Cannot commit empty form fields." : uiLogs s'}

handleVoteFormPopulationEvent ::
    ( MonadState UiState m
    , MonadIO m
    ) =>
    IORef Database -> Char -> m ()
handleVoteFormPopulationEvent dbRef i = withUnlockedState $ \_ -> do
    if isDigit i
        then do
            db <- liftIO $ readIORef dbRef
            let advert = pnLatestAdvert $ db V.! (digitToInt i - 1)
            modify $ \s ->
                s
                    { inputSlot = show $ pnSlotNo advert
                    , inputHash = pnBlockHash advert
                    }
        else pure ()

handleEvent :: IORef Database -> BrickEvent () UiEvent -> EventM () UiState ()
handleEvent dbRef event = case event of
    VtyEvent (V.EvKey V.KEsc []) -> halt
    AppEvent ReadFromDatabase -> do
        db <- liftIO $ readIORef dbRef
        let isSystemLocked = numVotesInFlight db > 0
        modify $ \st -> st{isSystemLocked = isSystemLocked, database = db}
    VtyEvent (V.EvKey (V.KChar 'p') []) -> handlePartitionEvent
    VtyEvent (V.EvKey (V.KChar 's') []) -> handleVoteSynthesisEvent dbRef
    VtyEvent (V.EvKey (V.KChar i) []) -> handleVoteFormPopulationEvent dbRef i
    _ -> return ()

--------------------------------------------------------------------------------
-- Application Loop Wiring
--------------------------------------------------------------------------------

app :: IORef Database -> App UiState UiEvent ()
app ioRef =
    App
        { appDraw = drawUi
        , appChooseCursor = showFirstCursor
        , appHandleEvent = handleEvent ioRef
        , appStartEvent = return ()
        , appAttrMap = const uiStyles
        }

main :: IO ()
main = do
    ioRef <- newIORef initialDB
    _ <- forkIO $ runHttpServer ioRef

    eventChan <- newBChan 10

    _ <- forkIO $ forever $ do
        threadDelay 200000
        writeBChan eventChan ReadFromDatabase

    let buildVty = mkVty V.defaultConfig
    initialVty <- buildVty
    void $ customMain initialVty buildVty (Just eventChan) (app ioRef) initialState
