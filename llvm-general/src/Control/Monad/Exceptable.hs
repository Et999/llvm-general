{-#LANGUAGE
  GeneralizedNewtypeDeriving
  ,MultiParamTypeClasses
  ,UndecidableInstances
  #-}
module Control.Monad.Exceptable(
      -- * MonadError class
    MonadError(..),

      -- * The Exceptable monad
    Exceptable,
    exceptable,
    runExceptable,
    mapExceptable,
    withExceptable,
    makeExceptableT,
    -- * The ExceptT monad transformer
    ExceptableT(ExceptableT),
    getExceptT,
    runExceptableT,
    mapExceptableT,
    withExceptableT,
    -- * Exception operations
    throwE,
    catchE,
    -- * Lifting other operations
    liftCallCC,
    liftListen,
    liftPass,
    -- * underlying ExceptT type
    Ext.Except,
    Ext.ExceptT,

    module Control.Monad,
    module Control.Monad.Fix,
    module Control.Monad.Trans,
    -- * Example 1: Custom Error Data Type
    -- $customErrorExample

    -- * Example 2: Using ExceptT Monad Transformer
    -- $ExceptTExample
    ) where

import qualified Control.Monad.Trans.Except as Ext

import  Control.Monad.Trans
--import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad.Signatures
--import Control.Monad.Trans.Class
import Data.Functor.Classes
import Data.Functor.Identity

--import qualified  Control.Monad.AnyCont.Class as AnyCont
import  Control.Monad.State.Class as State
import Control.Monad.Error.Class as Error

import Control.Applicative
import Control.Monad
import Control.Monad.Fix
import Data.Foldable
import Data.Traversable (Traversable(traverse))



type Exceptable e = ExceptableT e Identity

-- | Constructor for computations in the exception monad.
-- (The inverse of 'runExcept').
except :: Either e a -> Exceptable e a
except m = makeExceptableT (Identity m)

exceptable :: Ext.Except e a -> Exceptable e a
exceptable = ExceptableT

-- | Extractor for computations in the exception monad.
-- (The inverse of 'except').
runExceptable :: Exceptable e a -> Either e a
runExceptable (ExceptableT m) = runIdentity $ Ext.runExceptT m

-- | Map the unwrapped computation using the given function.
--
-- * @'runExcept' ('mapExcept' f m) = f ('runExcept' m)@
mapExceptable :: (Either e a -> Either e' b)
        -> Exceptable e a
        -> Exceptable e' b
mapExceptable f = mapExceptableT (Identity . f . runIdentity)

-- | Transform any exceptions thrown by the computation using the given
-- function (a specialization of 'withExceptT').
withExceptable :: (e -> e') -> Exceptable e a -> Exceptable e' a
withExceptable = withExceptableT



newtype ExceptableT e m a = ExceptableT { getExceptT :: Ext.ExceptT  e m a }
  deriving (Eq
    ,Eq1
    ,Ord
    ,Ord1
    ,Functor
    ,Foldable
    ,Applicative
    ,Alternative
    ,Monad
    ,MonadPlus
    ,MonadTrans
    ,MonadIO
    )

instance MonadState s m => MonadState s (ExceptableT e m) where
    get = lift get
    put = lift . put
    state = lift . state

instance Monad m => MonadError e (ExceptableT e m) where
    throwError = throwE
    catchError = catchE

instance (Traversable f) => Traversable (ExceptableT e f) where
    traverse f a =
        (ExceptableT . Ext.ExceptT) <$>
          traverse (either (pure . Left) (fmap Right . f)) (runExceptableT a)


instance (Read e, Read1 m, Read a) => Read (ExceptableT e m a) where
    readsPrec = readsData $ readsUnary1 "ExceptableT" ExceptableT

instance (Show e, Show1 m, Show a) => Show (ExceptableT e m a) where
    showsPrec d (ExceptableT m) = showsUnary1 "ExceptableT" d m

instance (Read e, Read1 m) => Read1 (ExceptableT e m) where readsPrec1 = readsPrec
instance (Show e, Show1 m) => Show1 (ExceptableT e m) where showsPrec1 = showsPrec

runExceptableT :: ExceptableT e m a -> m (Either e a)
runExceptableT =  Ext.runExceptT . getExceptT

makeExceptableT :: m (Either e a) -> ExceptableT e m a
makeExceptableT = ExceptableT . Ext.ExceptT




-- | Map the unwrapped computation using the given function.
--
-- * @'runExceptT' ('mapExceptT' f m) = f ('runExceptT' m)@
mapExceptableT :: (m (Either e a) -> n (Either e' b))
        -> ExceptableT e m a
        -> ExceptableT e' n b
mapExceptableT f m = makeExceptableT $ f (runExceptableT m)

-- | Transform any exceptions thrown by the computation using the
-- given function.
withExceptableT :: (Functor m) => (e -> e') -> ExceptableT e m a -> ExceptableT e' m a
withExceptableT f = mapExceptableT $ fmap $ either (Left . f) Right


-- | Signal an exception value @e@.
--
-- * @'runExceptT' ('throwE' e) = 'return' ('Left' e)@
--
-- * @'throwE' e >>= m = 'throwE' e@
throwE :: (Monad m) => e -> ExceptableT e m a
throwE = makeExceptableT . return . Left

-- | Handle an exception.
--
-- * @'catchE' h ('lift' m) = 'lift' m@
--
-- * @'catchE' h ('throwE' e) = h e@
catchE :: (Monad m) =>
    ExceptableT e m a               -- ^ the inner computation
    -> (e -> ExceptableT e' m a)    -- ^ a handler for exceptions in the inner
                                -- computation
    -> ExceptableT e' m a
m `catchE` h = makeExceptableT $ do
    a <- runExceptableT m
    case a of
        Left  l -> runExceptableT (h l)
        Right r -> return (Right r)

-- | Lift a @callCC@ operation to the new monad.
liftCallCC :: CallCC m (Either e a) (Either e b) -> CallCC (ExceptableT e m) a b
liftCallCC callCC f = makeExceptableT $
    callCC $ \ c ->
    runExceptableT (f (\ a -> makeExceptableT $ c (Right a)))

-- | Lift a @listen@ operation to the new monad.
liftListen :: (Monad m) => Listen w m (Either e a) -> Listen w (ExceptableT e m) a
liftListen listen = mapExceptableT $ \ m -> do
    (a, w) <- listen m
    return $! fmap (\ r -> (r, w)) a

-- | Lift a @pass@ operation to the new monad.
liftPass :: (Monad m) => Pass w m (Either e a) -> Pass w (ExceptableT e m) a
liftPass pass = mapExceptableT $ \ m -> pass $ do
    a <- m
    return $! case a of
        Left l -> (Left l, id)
        Right (r, f) -> (Right r, f)
