module Example.RealWorld.Types where

import Prelude

import Data.Either.Nested (Either2)
import Data.Functor.Coproduct.Nested (Coproduct2)
import Data.Maybe (Maybe)
import Effect.Aff (Aff)
import Example.RealWorld.Data.Group (Admin, Group, GroupForm)
import Example.RealWorld.Data.Options (Metric, Options, OptionsForm)
import Formless as Formless
import Ocelot.Components.Dropdown as Dropdown
import Ocelot.Components.Typeahead as TA

----------
-- Component

-- | This component will only handle output from Formless to keep
-- | things simple.
data Query a
  = HandleGroupForm (Formless.Message Query GroupForm Group) a
  | HandleOptionsForm (Formless.Message Query OptionsForm Options) a
  | HandleGroupTypeahead GroupTASlot (TA.Message Query String) a
  | HandleAdminDropdown (Dropdown.Message Query Admin) a
  | HandleMetricDropdown (Dropdown.Message Query Metric) a
  | Select Tab a
  | Reset a
  | Submit a

-- | We'll keep track of both form errors so we can show them in tabs
-- | and our ultimate goal is to result in a Group we can send to the
-- | server.
type State =
  { focus :: Tab                 -- Which tab is the user on?
  , groupFormErrors :: Int       -- Count of the group form errors
  , groupFormDirty :: Boolean    -- Is the group form in a dirty state?
  , optionsFormErrors :: Int     -- Count of the options form errors
  , optionsFormDirty :: Boolean  -- Is the options form in a dirty state?
  , group :: Maybe Group         -- Our ideal result type from form submission
  }

-- | Now we can create _this_ component's child query and child slot pairing.
type ChildQuery = Coproduct2
  (Formless.Query Query GroupCQ GroupCS GroupForm Group Aff)
  (Formless.Query Query OptionsCQ OptionsCS OptionsForm Options Aff)

type ChildSlot = Either2
  Unit
  Unit

----------
-- Formless

-- | Types for the group form
type GroupCQ = Coproduct2
  (TA.Query Query String String Aff)
  (Dropdown.Query Query Admin Aff)

type GroupCS = Either2
  GroupTASlot
  Unit

-- | Types for the options form
type OptionsCQ = Dropdown.Query Query Metric Aff
type OptionsCS = Unit

----------
-- Slots

data GroupTASlot
  = ApplicationsTypeahead
  | PixelsTypeahead
  | WhiskeyTypeahead
derive instance eqGroupTASlot :: Eq GroupTASlot
derive instance ordGroupTASlot :: Ord GroupTASlot

----------
-- Navigation

data Tab
  = GroupFormTab
  | OptionsFormTab
derive instance eqTab :: Eq Tab
derive instance ordTab :: Ord Tab
