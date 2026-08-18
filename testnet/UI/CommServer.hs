{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

module UI.CommServer where

import Data.IORef (IORef, atomicModifyIORef')
import qualified Data.Vector as V
import Web.Scotty
import Misc (env_CARDANO_TESTNET_NUM_NODES)

--------------------------------------------------------------------------------
-- Database
--------------------------------------------------------------------------------

data Advert = Advert
    { pnNumVotes :: Int
    , pnNumCerts :: Int
    , pnChainLen :: Int
    , pnPerasBoost :: Int
    , pnSlotNo :: Int
    , pnBlockHash :: String
    , pnBlockNo :: Int
    } deriving (Show)

data PerNodeInfo = PerNodeInfo
    { pnLatestAdvert :: Advert
    }

type Database = V.Vector PerNodeInfo

initialDB :: Database
initialDB =
    V.replicate
        env_CARDANO_TESTNET_NUM_NODES
        (PerNodeInfo (Advert 0 0 0 0 0 (replicate 32 ' ') 0))

toVecIndex :: Int -> Int
toVecIndex i = i - 1

addAdvertInfo :: Int -> Advert -> Database -> Database
addAdvertInfo nodeIndex advert db = do
    let vecIndex = toVecIndex nodeIndex
        old      = db V.! vecIndex
        new      = old { pnLatestAdvert = advert }
     in db V.// [(vecIndex, new)]

--------------------------------------------------------------------------------
-- Server
--------------------------------------------------------------------------------

runHttpServer :: IORef Database -> IO ()
runHttpServer ioRef = scotty 9000 $ do
    get "/advert" $ do
        nodeId <- read . drop 4 <$> queryParam "node_id"
        numCerts <- read <$> queryParam "num_certs"
        numVotes <- read <$> queryParam "num_votes"
        chainLen <- read <$> queryParam "chain_len"
        perasBoost <- read <$> queryParam "peras_boost"
        slotNo <- read <$> queryParam "slot_no"
        blockHash <- queryParam "block_hash"
        blockNo <- read <$> queryParam "block_no"
        let advert =
                Advert
                    { pnNumVotes = numVotes
                    , pnNumCerts = numCerts
                    , pnChainLen = chainLen
                    , pnPerasBoost = perasBoost
                    , pnSlotNo = slotNo
                    , pnBlockHash = blockHash
                    , pnBlockNo = blockNo
                    }
        liftIO $ atomicModifyIORef' ioRef $ \old ->
            ( addAdvertInfo nodeId advert old
            , ()
            )
