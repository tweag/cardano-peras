{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

module UI.CommServer where

import Data.IORef (IORef, atomicModifyIORef')
import qualified Data.Vector as V
import qualified Data.Text.Lazy as TL
import Web.Scotty
import Misc (env_CARDANO_TESTNET_NUM_NODES)

--------------------------------------------------------------------------------
-- Database
--------------------------------------------------------------------------------

data PerNodeInfo = PerNodeInfo
  { pnVoteCreateRequest :: Maybe (Int, String)
  , pnNumVotes :: Int
  , pnNumCerts :: Int
  }

type Database = V.Vector PerNodeInfo

initialDB :: Database
initialDB = V.replicate env_CARDANO_TESTNET_NUM_NODES (PerNodeInfo Nothing 0 0)

toVecIndex :: Int -> Int
toVecIndex i = i - 1

addVoteCreateRequestToAllNodes :: (Int, String) -> Database -> Database
addVoteCreateRequestToAllNodes vote =
    V.map (\old -> old { pnVoteCreateRequest = Just vote })

removeVoteCreateRequestFrom :: Int -> Database -> Database
removeVoteCreateRequestFrom nodeIndex db = do
    let vecIndex = toVecIndex nodeIndex
        old      = db V.! vecIndex
        new      = old { pnVoteCreateRequest = Nothing }
     in db V.// [(vecIndex, new)]

addAdvertInfo :: Int -> Int -> Int -> Database -> Database
addAdvertInfo nodeIndex numVotes numCerts db = do
    let vecIndex = toVecIndex nodeIndex
        old      = db V.! vecIndex
        new      = old { pnNumVotes = numVotes, pnNumCerts = numCerts }
     in db V.// [(vecIndex, new)]

numVotesInFlight :: Database -> Int
numVotesInFlight =
    V.foldl' (\b a -> maybe 0 (const 1) (pnVoteCreateRequest a) + b) 0

getVoteCreatingDetails :: Int -> Database -> Maybe (Int, String)
getVoteCreatingDetails nodeIndex db =
    pnVoteCreateRequest $ db V.! toVecIndex nodeIndex

--------------------------------------------------------------------------------
-- Server
--------------------------------------------------------------------------------

runHttpServer :: IORef Database -> IO ()
runHttpServer ioRef = scotty 9000 $ do
    get "/vote_creation_details" $ do
        nodeId <- queryParam "node_id"
        res <-
            liftIO $ atomicModifyIORef' ioRef $ \old ->
                ( removeVoteCreateRequestFrom nodeId old
                , getVoteCreatingDetails nodeId old
                )
        text $ TL.pack $ show res
    get "/advert" $ do
        nodeId <- queryParam "node_id"
        numCerts <- read <$> queryParam "num_certs"
        numVotes <- read <$> queryParam "num_votes"
        liftIO $ atomicModifyIORef' ioRef $ \old ->
            ( addAdvertInfo nodeId numVotes numCerts old
            , ()
            )
