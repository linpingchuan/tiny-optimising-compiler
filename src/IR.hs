{-# LANGUAGE GADTs #-}
module IR where
import Data.Text.Prettyprint.Doc as PP
import qualified Language as L
import qualified Data.List.NonEmpty as NE
import qualified Data.Map as M

data SSA
data NotSSA

-- | A label that uses the phantom @a as a type based discriminator
data Label a = Label { unLabel ::  String } deriving(Eq, Ord)
instance Pretty (Label a) where
  pretty (Label s) = pretty s

-- a Value, which can either be a constant, or a reference to an instruction.
data Value = ValueConstInt Int | ValueInstRef (Label Inst)

instance Pretty Value where
  pretty (ValueConstInt i) = pretty i <> pretty "#"
  pretty (ValueInstRef name) = pretty "%" <> pretty name

-- | Instructions that we allow within a basic block.
data Inst  where
  InstAlloc :: Inst
  InstAdd :: Value -> Value -> Inst
  InstMul :: Value -> Value -> Inst
  InstL :: Value -> Value -> Inst
  InstAnd :: Value -> Value -> Inst
  InstLoad :: Value -> Inst
  InstStore :: Value -> Value -> Inst
  InstPhi :: NE.NonEmpty (BBId, Value) -> Inst

instance Pretty Inst where
  pretty (InstAlloc) = pretty "alloc"
  pretty (InstAdd l r) = pretty "add" <+> pretty l <+> pretty r
  pretty (InstMul l r) = pretty "mul" <+> pretty l <+> pretty r
  pretty (InstL l r) = pretty "lessthan" <+> pretty l <+> pretty r
  pretty (InstAnd l r) = pretty "and" <+> pretty l <+> pretty r
  pretty (InstLoad op) = pretty "load" <+> pretty op
  pretty (InstStore slot val) = pretty "store" <+> pretty val <+>
                                pretty "in" <+> pretty slot
  pretty (InstPhi philist) =
    pretty "Phi: " <+> hcat (punctuate comma (NE.toList (fmap (\(bbid, val) ->
                                brackets (pretty bbid <+> pretty val)) philist)))

-- | Represents @a that is optionally named by a @Label a
data Named a = Named { namedName :: Label a, namedData :: a }


-- | Infix operator for @Named constructor
(=:=) :: Label a  -> a -> Named a
name =:= a = Named name a


instance Pretty a => Pretty (Named a) where
  pretty (Named name data') = pretty name <+> pretty ":=" <+> pretty data'

-- | Used to identify basic blocks
type BBId = Label BasicBlock
-- | A basic block. Single-entry, multiple-exit.
data BasicBlock = BasicBlock { bbInsts :: [Named Inst], bbRetInst :: RetInst , bbLabel :: Label BasicBlock }

-- | Default basic block.
defaultBB :: BasicBlock
defaultBB = BasicBlock [] (RetInstTerminal) (Label "undefined")

-- TODO: replace nest with indent
instance Pretty BasicBlock where
  pretty (BasicBlock insts ret label) =
    nest 4 (vsep ([pretty label <> pretty ":"] ++ body)) where
      body = map pretty insts ++ [pretty ret]


-- | Return instructions are the only ones that can cause control flow
-- | between one basic block to another.
data RetInst =
  RetInstConditionalBranch Value BBId BBId |
  RetInstBranch BBId |
  RetInstTerminal

instance Pretty RetInst where
  pretty (RetInstTerminal) = pretty "TERMINAL"
  pretty (RetInstBranch next) = pretty "branch" <+> pretty next
  pretty (RetInstConditionalBranch cond then' else') = pretty "branch if" <+> pretty cond <+> pretty "then" <+> pretty then' <+> pretty "else" <+> pretty else'

data IRProgram = IRProgram {
  irProgramBBMap :: M.Map BBId BasicBlock,
  irProgramEntryBBId :: BBId
}

instance Pretty IRProgram where
  pretty (IRProgram bbmap entryId) = vsep [pretty "entry: " <+> pretty entryId, pretty (M.elems bbmap)]
