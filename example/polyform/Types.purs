module Example.Polyform.Types where

import Prelude

import Data.Const (Const)
import Effect.Aff (Aff)
import Example.Polyform.Spec (Form, User)
import Formless as F

----------
-- Component

-- | This component just handles Formless
data Query a
  = HandleFormless (F.Message Query Form User) a

type State = Unit

-- | Now we can create _this_ component's child query and child slot pairing.
type ChildQuery = F.Query Query FCQ FCS Form User Aff
type ChildSlot = Unit

----------
-- Formless

-- | FCQ: Formless ChildQuery
-- | FCS: Formless ChildSlot
type FCQ = Const Void
type FCS = Unit
