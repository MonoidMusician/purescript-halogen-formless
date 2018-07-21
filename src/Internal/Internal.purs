module Formless.Internal where

import Prelude

import Data.Either (Either(..), hush)
import Data.Maybe (Maybe(..))
import Data.Monoid.Additive (Additive(..))
import Data.Newtype (class Newtype, unwrap, wrap)
import Data.Symbol (class IsSymbol, SProxy(..))
import Formless.Spec (FormSpec(..), InputField(..), OutputField(..))
import Prim.Row as Row
import Prim.RowList as RL
import Record as Record
import Record.Builder (Builder)
import Record.Builder as Builder
import Type.Data.RowList (RLProxy(..))
import Type.Row (class ListToRow)

-- I build all my records from scratch
type FromScratch r = Builder {} {|r}
fromScratch :: forall r. FromScratch r -> Record r
fromScratch = Builder.build <@> {}

-----
-- Types

-- | Never exposed to the user, but used to aid equality instances for
-- | checking dirty states.
newtype Input i e o = Input i
derive instance newtypeInput :: Newtype (Input i e o) _
derive newtype instance eqInput :: Eq i => Eq (Input i e o)

-----
-- Functions

-- | Unwraps all the fields in a record, so long as all fields have newtypes
unwrapRecord
  :: ∀ row xs row'
   . RL.RowToList row xs
  => UnwrapRecord xs row row'
  => Record row
  -> Record row'
unwrapRecord r = fromScratch builder
  where
    builder = unwrapRecordBuilder (RLProxy :: RLProxy xs) r

-- | Wraps all the fields in a record, so long as all fields have proper newtype
-- | instances
wrapRecord
  :: ∀ row xs row'
   . RL.RowToList row xs
  => WrapRecord xs row row'
  => Record row
  -> Record row'
wrapRecord r = fromScratch builder
  where
    builder = wrapRecordBuilder (RLProxy :: RLProxy xs) r

-- | Sequences a record of applicatives. Useful when applying monadic field validation
-- | so you can recover the proper type for the Formless validation function. Does not
-- | operate on newtypes, so you'll want to unwrap / re-wrap your form type when using.
sequenceRecord :: ∀ row row' rl m
   . RL.RowToList row rl
  => SequenceRecord rl row row' m
  => Record row
  -> m (Record row')
sequenceRecord a = fromScratch <$> builder
  where
		builder = sequenceRecordImpl (RLProxy :: RLProxy rl) a

-- | A helper function that will count all errors in a record
checkTouched
  :: ∀ form row xs
   . RL.RowToList row xs
  => AllTouched xs row
  => Newtype (form InputField) (Record row)
  => form InputField
  -> Boolean
checkTouched = allTouchedImpl (RLProxy :: RLProxy xs) <<< unwrap

-- | A helper function that will count all errors in a record
countErrors
  :: ∀ form row xs row' xs'
   . RL.RowToList row xs
  => RL.RowToList row' xs'
  => CountErrors xs row row'
  => SumRecord xs' row' (Additive Int)
  => Newtype (form InputField) (Record row)
  => form InputField
  -> Int
countErrors r = unwrap $ sumRecord $ fromScratch builder
  where
    builder = countErrorsBuilder (RLProxy :: RLProxy xs) (unwrap r)

-- | A helper function that sums a monoidal record
sumRecord
  :: ∀ r rl a
   . SumRecord rl r a
  => RL.RowToList r rl
  => Record r
  -> a
sumRecord r = sumImpl (RLProxy :: RLProxy rl) r

-- | A helper function that will set all input fields to 'touched = true'. This ensures
-- | subsequent validations apply to all fields even if not edited by the user.
setInputFieldsTouched
  :: ∀ row xs form
   . RL.RowToList row xs
  => SetInputFieldsTouched xs row row
  => Newtype (form InputField) (Record row)
  => form InputField
  -> form InputField
setInputFieldsTouched r = wrap $ fromScratch builder
  where
    builder = setInputFieldsTouchedBuilder (RLProxy :: RLProxy xs) (unwrap r)

-- | A helper function that will automatically transform a record of InputField(s) into
-- | just the input value
inputFieldsToInput
  :: ∀ row xs row' form
   . RL.RowToList row xs
  => InputFieldsToInput xs row row'
  => Newtype (form InputField) (Record row)
  => Newtype (form Input) (Record row')
  => form InputField
  -> form Input
inputFieldsToInput r = wrap $ fromScratch builder
  where
    builder = inputFieldsToInputBuilder (RLProxy :: RLProxy xs) (unwrap r)

-- | A helper function that will automatically transform a record of FormSpec(s) into
-- | a record of InputField(s).
formSpecToInputFields
  :: ∀ row xs row' form
   . RL.RowToList row xs
  => FormSpecToInputField xs row row'
  => Newtype (form FormSpec) (Record row)
  => Newtype (form InputField) (Record row')
  => form FormSpec
  -> form InputField
formSpecToInputFields r = wrap $ fromScratch builder
  where
    builder = formSpecToInputFieldBuilder (RLProxy :: RLProxy xs) (unwrap r)

-- | An intermediate function that transforms a record of InputField into a record
-- | of MaybeOutput as a step in producing output fields.
inputFieldToMaybeOutput
  :: ∀ row xs row' form
   . RL.RowToList row xs
  => InputFieldToMaybeOutput xs row row'
  => Newtype (form InputField) (Record row)
  => Newtype (form OutputField) (Record row')
  => form InputField
  -> Maybe (form OutputField)
inputFieldToMaybeOutput r = map wrap $ fromScratch <$> builder
  where
    builder = inputFieldToMaybeOutputBuilder (RLProxy :: RLProxy xs) (unwrap r)

-----
-- Classes (Internal)

-- Helper classes (one might call them internal to the internal classes)
-- Essentially a constraint synonym for Row.Cons and Row.Lacks
class (Row.Cons s t r r', Row.Lacks s r) <= Row1Cons s t r r' | s t r -> r', s r' -> t r
instance row1Cons :: (Row.Cons s t r r', Row.Lacks s r) => Row1Cons s t r r'

-- ListToRow is the left inverse of RowToList, so this makes sense
class (RL.RowToList r rl, ListToRow rl r) <= RowRowList r rl | r -> rl, rl -> r
instance rowRowList :: (RL.RowToList r rl, ListToRow rl r) => RowRowList r rl

class (Row1Cons s t r r', RowRowList r rl, RowRowList r' rl')
  <= RowRowRowYourBoat s t r r' rl rl'
  | rl' -> s t r r' rl
  , rl -> r
  , s t r -> r' rl rl'
  , s t rl -> r r' rl'
instance rowRowRowYourBoat ::
  (Row1Cons s t r r', RowRowList r rl, RowRowList r' (RL.Cons s t rl))
  => RowRowRowYourBoat s t r r' rl (RL.Cons s t rl)

-- | A class to set all input fields to touched for validation purposes
class SetInputFieldsTouched
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  setInputFieldsTouchedBuilder :: RLProxy xs -> Record row -> FromScratch to

instance setInputFieldsTouchedNil :: SetInputFieldsTouched RL.Nil row () where
  setInputFieldsTouchedBuilder _ _ = identity

instance setInputFieldsTouchedCons
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) trash row
     , SetInputFieldsTouched tail row from
     , Row1Cons name (InputField i e o) from to
     )
  => SetInputFieldsTouched (RL.Cons name (InputField i e o) tail) row to where
  setInputFieldsTouchedBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = setInputFieldsTouchedBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (InputField i) = InputField i { touched = true }

-- | The class that provides the Builder implementation to efficiently transform the record
-- | of FormSpec to record of InputField.
class InputFieldsToInput
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  inputFieldsToInputBuilder :: RLProxy xs -> Record row -> FromScratch to

instance inputFieldsToInputNil :: InputFieldsToInput RL.Nil row () where
  inputFieldsToInputBuilder _ _ = identity

instance inputFieldsToInputCons
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) trash row
     , InputFieldsToInput tail row from
     , Row1Cons name (Input i e o) from to
     )
  => InputFieldsToInput (RL.Cons name (InputField i e o) tail) row to where
  inputFieldsToInputBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = inputFieldsToInputBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (InputField fields) = Input fields.input

-- | The class that provides the Builder implementation to efficiently transform the record
-- | of FormSpec to record of InputField.
class FormSpecToInputField
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  formSpecToInputFieldBuilder :: RLProxy xs -> Record row -> FromScratch to

instance formSpecToInputFieldNil :: FormSpecToInputField RL.Nil row () where
  formSpecToInputFieldBuilder _ _ = identity

instance formSpecToInputFieldCons
  :: ( IsSymbol name
     , Row.Cons name (FormSpec i e o) trash row
     , FormSpecToInputField tail row from
     , Row1Cons name (InputField i e o) from to
     )
  => FormSpecToInputField (RL.Cons name (FormSpec i e o) tail) row to where
  formSpecToInputFieldBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = formSpecToInputFieldBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (FormSpec input) = InputField
        { input
        , touched: false
        , result: Nothing
        }

-- | The class that provides the Builder implementation to efficiently transform the record
-- | of MaybeOutput to a record of OutputField, but only if all fields were successfully
-- | validated.
class InputFieldToMaybeOutput
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  inputFieldToMaybeOutputBuilder :: RLProxy xs -> Record row -> Maybe (FromScratch to)

instance inputFieldToMaybeOutputNil :: InputFieldToMaybeOutput RL.Nil row () where
  inputFieldToMaybeOutputBuilder _ _ = Just identity

instance inputFieldToMaybeOutputCons
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) trash row
     , InputFieldToMaybeOutput tail row from
     , Row1Cons name (OutputField i e o) from to
     )
  => InputFieldToMaybeOutput (RL.Cons name (InputField i e o) tail) row to where
  inputFieldToMaybeOutputBuilder _ r =
    transform <$> val <*> rest
    where
      _name = SProxy :: SProxy name

      val :: Maybe (OutputField i e o)
      val = map OutputField $ join $ map hush $ _.result $ unwrap $ Record.get _name r

      rest :: Maybe (FromScratch from)
      rest = inputFieldToMaybeOutputBuilder (RLProxy :: RLProxy tail) r

      transform
        :: OutputField i e o
        -> FromScratch from
        -> FromScratch to
      transform v builder' = Builder.insert _name v <<< builder'


-- | A class to sum a monoidal record
class Monoid a <= SumRecord (rl :: RL.RowList) (r :: # Type) a | rl -> a where
  sumImpl :: RLProxy rl -> Record r -> a

instance nilSumRecord :: Monoid a => SumRecord RL.Nil r a where
  sumImpl _ _ = mempty

instance consSumRecord
  :: ( IsSymbol name
     , Monoid a
     , Row.Cons name a t0 r
     , SumRecord tail r a
     )
  => SumRecord (RL.Cons name a tail) r a
  where
    sumImpl _ r =
      -- This has to be defined in a variable for some reason; it won't
      -- compile otherwise, but I don't know why not.
      let tail' = sumImpl (RLProxy :: RLProxy tail) r
          val = Record.get (SProxy :: SProxy name) r
       in val <> tail'

-- | Gets out ints
class CountErrors
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  countErrorsBuilder :: RLProxy xs -> Record row -> FromScratch to

instance countErrorsNil :: CountErrors RL.Nil row () where
  countErrorsBuilder _ _ = identity

instance countErrorsCons
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) trash row
     , CountErrors tail row from
     , Row1Cons name (Additive Int) from to
     )
  => CountErrors (RL.Cons name (InputField i e o) tail) row to where
  countErrorsBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = countErrorsBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (InputField { result }) =
        case result of
          Just (Left _) -> Additive 1
          _ -> Additive 0


-- | A class to check if all fields in an InputField record have been touched or not
class AllTouched (rl :: RL.RowList) (r :: # Type) where
  allTouchedImpl :: RLProxy rl -> Record r -> Boolean

instance nilAllTouched :: AllTouched RL.Nil r where
  allTouchedImpl _ _ = true

instance consAllTouched
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) t0 r
     , AllTouched tail r
     )
  => AllTouched (RL.Cons name (InputField i e o) tail) r
  where
    allTouchedImpl _ r =
      if (unwrap (Record.get (SProxy :: SProxy name) r)).touched
      then allTouchedImpl (RLProxy :: RLProxy tail) r
      else false


-- | The class to efficiently unwrap a record of newtypes
class UnwrapRecord
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  unwrapRecordBuilder :: RLProxy xs -> Record row -> FromScratch to

instance unwrapRecordNil :: UnwrapRecord RL.Nil row () where
  unwrapRecordBuilder _ _ = identity

instance unwrapRecordCons
  :: ( IsSymbol name
     , Row.Cons name wrapper trash row
     , Newtype wrapper x
     , UnwrapRecord tail row from
     , Row1Cons name x from to
     )
  => UnwrapRecord (RL.Cons name wrapper tail) row to where
  unwrapRecordBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = unwrap $ Record.get _name r
      rest = unwrapRecordBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val


-- | The class to efficiently wrap a record of newtypes
class WrapRecord
  (xs :: RL.RowList) (row :: # Type) (to :: # Type)
  | xs -> to where
  wrapRecordBuilder :: RLProxy xs -> Record row -> FromScratch to

instance wrapRecordNil :: WrapRecord RL.Nil row () where
  wrapRecordBuilder _ _ = identity

instance wrapRecordCons
  :: ( IsSymbol name
     , Row.Cons name x trash row
     , Newtype wrapper x
     , WrapRecord tail row from
     , Row1Cons name wrapper from to
     )
  => WrapRecord (RL.Cons name x tail) row to where
  wrapRecordBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = wrap $ Record.get _name r
      rest = wrapRecordBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val

-- | The class to efficiently run the sequenceRecord function on a record.
class Applicative m <= SequenceRecord rl row to m
  | rl -> row to m
  where
    sequenceRecordImpl :: RLProxy rl -> Record row -> m (FromScratch to)

instance sequenceRecordCons ::
  ( IsSymbol name
  , Applicative m
  , Row.Cons name (m ty) trash row
  , SequenceRecord tail row from m
  , Row1Cons name ty from to
  ) => SequenceRecord (RL.Cons name (m ty) tail) row to m where
  sequenceRecordImpl _ a  =
       fn <$> valA <*> rest
    where
      namep = SProxy :: SProxy name
      valA = Record.get namep a
      tailp = RLProxy :: RLProxy tail
      rest = sequenceRecordImpl tailp a
      fn valA' rest' = Builder.insert namep valA' <<< rest'

instance sequenceRecordNil :: Applicative m => SequenceRecord RL.Nil row () m where
  sequenceRecordImpl _ _ = pure identity

-- | A class to reduce the type variables required to use applyRecord
class ApplyRecord (io :: # Type) (i :: # Type) (o :: # Type)
  | io -> i o
  , i -> io o
  , o -> io i
  where
  applyRecord :: Record io -> Record i -> Record o

instance applyRecordImpl
  :: ( RowRowList io lio
     , RowRowList i li
     , RowRowList o lo
     , ApplyRowList lio li lo io i io i o
     )
  => ApplyRecord io i o where
  applyRecord io i = Builder.build (builder io i) {}
    where
      builder =
        applyRowList
        (RLProxy :: RLProxy lio)
        (RLProxy :: RLProxy li)
        (RLProxy :: RLProxy lo)

-- | Modified from the original by @LiamGoodacre
-- | Applies a record of functions to a record of input values to produce
-- | a record of outputs.
class
  ( RowRowList ior io
  , RowRowList ir i
  , RowRowList or o
  ) <=
  ApplyRowList
    (io :: RL.RowList)
    (i :: RL.RowList)
    (o :: RL.RowList)
    (ior :: # Type)
    (ir :: # Type)
    (iorf :: # Type)
    (irf :: # Type)
    (or :: # Type)
    | io -> i o ior ir or
    , i -> io o ior ir or
    , o -> io i ior ir or
  where
  applyRowList
    :: RLProxy io
    -> RLProxy i
    -> RLProxy o
    -> Record iorf
    -> Record irf
    -> FromScratch or

instance applyRowListNil :: ApplyRowList RL.Nil RL.Nil RL.Nil () () iorf irf () where
  applyRowList _ _ _ _ _ = identity

instance applyRowListCons
  :: ( Row.Cons k (i -> o) unused1 iorf
     , Row.Cons k i unused2 irf
     , RowRowRowYourBoat k (i -> o) tior ior tio (RL.Cons k (i -> o) tio)
     , RowRowRowYourBoat k i tir ir ti (RL.Cons k i ti)
     , RowRowRowYourBoat k o tor or to (RL.Cons k o to)
     , ListToRow (RL.Cons k (i -> o) tio) ior
     , ListToRow (RL.Cons k i ti) ir
     , ApplyRowList tio ti to tior tir iorf irf tor
     , IsSymbol k
     )
  => ApplyRowList
       (RL.Cons k (i -> o) tio)
       (RL.Cons k i ti)
       (RL.Cons k o to)
       ior
       ir
       iorf
       irf
       or
  where
    applyRowList io i o ior ir =
      fir <<< tor
      where
        _key = SProxy :: SProxy k

        f :: i -> o
        f = Record.get _key ior

        x :: i
        x = Record.get _key ir

        fir :: Builder { | tor } { | or }
        fir = Builder.insert _key (f x)

        tor :: FromScratch tor
        tor = applyRowList (rltail io) (rltail i) (rltail o) ior ir


rltail :: ∀ k v t. RLProxy (RL.Cons k v t) -> RLProxy t
rltail _ = RLProxy
