{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module UI where

import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forever, void)
import Control.Monad.IO.Class (liftIO)
import Data.ByteString.Char8 qualified as BC
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Text.Read (readMaybe)

-- Imports for low-level stream hijacking

import Control.Exception (finally)
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import System.Directory (removeFile)
import System.IO (IOMode (WriteMode), hClose, hFlush, openFile, stderr, stdout)

-- Brick Core & Async Events Imports
import Brick
import Brick.BChan (newBChan, writeBChan)
import Brick.Widgets.Border as B
import Brick.Widgets.Center as C
import Data.Vector qualified as V
import Graphics.Vty qualified as V
import Graphics.Vty.Platform.Unix (mkVty)

import Network

import Control.Monad.State.Class (MonadState)

import UI.CommServer

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

data UiEvent = ReadFromDatabase

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
    B.borderWithLabel (str " Vote Configuration ") $
        vBox
            [ str "Slot Number:      " <+> withAttr inputAttr (str (if null (inputSlot st) then "<empty>" else inputSlot st))
            , str "Block Hash:       " <+> withAttr inputAttr (str (if null (inputHash st) then "<empty>" else inputHash st))
            , -- NEW: Visual status display for the partition toggle state
              str "Partition Status: "
                <+> ( if partitionActive st
                        then withAttr partitionOnAttr (str "ACTIVE")
                        else withAttr partitionOffAttr (str "INACTIVE")
                    )
            ]

nodeTipsDisplay :: UiState -> Widget ()
nodeTipsDisplay st =
    B.borderWithLabel (str " Fetched Node Tips ") $
        if null (fetchedTips st)
            then C.hCenter $ padAll 1 $ str "No data fetched yet. Press [F] to query nodes."
            else vBox (map drawRow (fetchedTips st))
  where
    drawRow tip =
        let nameTag = withAttr nodeNameAttr $ str (padString 10 (ntNodeName tip))
            details =
                str $
                    " | Block: "
                        ++ padString 8 (ntBlockNo tip)
                        ++ " | Slot: "
                        ++ padString 8 (ntSlotNo tip)
                        ++ " | Hash: "
                        ++ ntBlockHash tip
         in nameTag <+> details

logsDisplay :: UiState -> Widget ()
logsDisplay st =
    B.borderWithLabel (str " Logs ") $
        let visibleLogs = take 4 (uiLogs st)
         in if null visibleLogs then str " " else vBox (map (withAttr logTextAttr . str) visibleLogs)

databaseTableDisplay :: UiState -> Widget ()
databaseTableDisplay st =
    B.borderWithLabel (str " Per-Node Database Registry ") $
        padTopBottom 1 $
            padLeftRight 2 $
                vBox $
                    headerRow : hBorder : bodyRows
  where
    db = database st

    -- Table Header
    headerRow =
        withAttr nodeNameAttr $
            str (padString 12 "Node Index" ++ " | " ++ "Active Vote Payload Status")

    -- Table Body
    bodyRows =
        if V.null db
            then [str "No registered node data found in shared memory."]
            else map drawRow (V.toList (V.indexed db))

    drawRow (idx, info) =
        let nodeLabel = "Node [" ++ show (idx + 1) ++ "]"
            payloadText = case pnVoteCreateRequest info of
                Nothing -> withAttr partitionOffAttr (str "No active vote request")
                Just (slot, hash) ->
                    withAttr inputAttr (str $ "Slot: " ++ show slot ++ " (Hash: " ++ take 8 hash ++ "...)")
         in str (padString 12 nodeLabel ++ " | ") <+> payloadText

drawUi :: UiState -> [Widget ()]
drawUi st =
    [ C.center $
        B.borderWithLabel (str " Node Tip Monitor ") $
            vBox
                [ drawStatusBanner (isSystemLocked st)
                , padAll 1 $ voteForm st
                , padLeftRight 1 $ databaseTableDisplay st
                , padLeftRight 1 $ nodeTipsDisplay st
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
drawActionInstructions False = str "[f]: Fetch | [v]: Generate Vote | [p]: Toggle Partition | [esc]: Exit"
drawActionInstructions True = withAttr warningAttr $ str "Control locked until votes are processed"

padString :: Int -> String -> String
padString n s = s ++ replicate (max 0 (n - length s)) ' '

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

handleEvent :: IORef Database -> BrickEvent () UiEvent -> EventM () UiState ()
handleEvent dbRef event = case event of
    VtyEvent (V.EvKey V.KEsc []) -> halt
    AppEvent ReadFromDatabase -> do
        db <- liftIO $ readIORef dbRef
        let isSystemLocked = numVotesInFlight db > 0
        modify $ \st -> st{isSystemLocked = isSystemLocked, database = db}

    -- NEW: Partition Key Toggle Action Handler
    VtyEvent (V.EvKey (V.KChar 'p') []) -> withUnlockedState $ \st ->
        if partitionActive st
            then do
                -- Partition is active -> Remove it
                ((), interceptedLogs) <- liftIO $ captureExternalOutputs removeToxicity
                modify $ \s ->
                    s
                        { partitionActive = False
                        , uiLogs = interceptedLogs ++ ["Partition removed."] ++ uiLogs s
                        }
            else do
                -- Partition is inactive -> Create it
                ((), interceptedLogs) <- liftIO $ captureExternalOutputs addToxicity
                modify $ \s ->
                    s
                        { partitionActive = True
                        , uiLogs = interceptedLogs ++ ["Partition created."] ++ uiLogs s
                        }
    VtyEvent (V.EvKey (V.KChar 'f') []) -> withUnlockedState $ \_ -> do
        (tips, interceptedLogs) <- liftIO $ captureExternalOutputs getNodeTips
        let targetNode = head tips
        modify $ \s ->
            s
                { fetchedTips = tips
                , inputSlot = ntSlotNo targetNode
                , inputHash = ntBlockHash targetNode
                , uiLogs = interceptedLogs ++ uiLogs s
                }
    VtyEvent (V.EvKey (V.KChar 'v') []) -> withUnlockedState $ \st -> do
        case (readMaybe (inputSlot st) :: Maybe Int, inputHash st) of
            (Just s, h) | not (null h) -> do
                liftIO $ atomicModifyIORef' dbRef ((,()) . addVoteCreateRequestToAllNodes (s, h))
                modify $ \s' ->
                    s'
                        { isSystemLocked = True
                        , uiLogs = "Successfully sent payload to shared IORef memory. Controls locked." : uiLogs s'
                        }
            _ ->
                modify $ \s' -> s'{uiLogs = "Error: Cannot commit empty form fields." : uiLogs s'}
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
