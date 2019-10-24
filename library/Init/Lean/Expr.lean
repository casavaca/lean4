/-
Copyright (c) 2018 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
prelude
import Init.Lean.Level
import Init.Lean.KVMap
import Init.Data.HashMap
import Init.Data.PersistentHashMap

namespace Lean

inductive Literal
| natVal (val : Nat)
| strVal (val : String)

inductive BinderInfo
| default | implicit | strictImplicit | instImplicit | auxDecl

namespace BinderInfo

def isInstImplicit : BinderInfo → Bool
| instImplicit => true
| _            => false

protected def beq : BinderInfo → BinderInfo → Bool
| default, default => true
| implicit, implicit => true
| strictImplicit, strictImplicit => true
| instImplicit, instImplicit => true
| auxDecl, auxDecl => true
| _, _ => false

instance : HasBeq BinderInfo := ⟨BinderInfo.beq⟩

end BinderInfo

abbrev MData := KVMap
namespace MData
abbrev empty : MData := {KVMap .}
instance : HasEmptyc MData := ⟨empty⟩
end MData

/- We use the `E` suffix (short for `Expr`) to avoid collision with keywords.
   We considered using «...», but it is too inconvenient to use. -/
inductive Expr
| bvar    : Nat → Expr                                -- bound variables
| fvar    : Name → Expr                               -- free variables
| mvar    : Name → Expr                               -- meta variables
| sort    : Level → Expr                              -- Sort
| const   : Name → List Level → Expr                  -- constants
| app     : Expr → Expr → Expr                        -- application
| lam     : Name → BinderInfo → Expr → Expr → Expr    -- lambda abstraction
| forallE : Name → BinderInfo → Expr → Expr → Expr    -- (dependent) arrow
| letE    : Name → Expr → Expr → Expr → Expr          -- let expressions
| lit     : Literal → Expr                            -- literals
| mdata   : MData → Expr → Expr                       -- metadata
| proj    : Name → Nat → Expr → Expr                  -- projection

instance exprIsInhabited : Inhabited Expr :=
⟨Expr.sort Level.zero⟩

attribute [extern "lean_expr_mk_bvar"]   Expr.bvar
attribute [extern "lean_expr_mk_fvar"]   Expr.fvar
attribute [extern "lean_expr_mk_mvar"]   Expr.mvar
attribute [extern "lean_expr_mk_sort"]   Expr.sort
attribute [extern "lean_expr_mk_const"]  Expr.const
attribute [extern "lean_expr_mk_app"]    Expr.app
attribute [extern "lean_expr_mk_lambda"] Expr.lam
attribute [extern "lean_expr_mk_pi"]     Expr.forallE
attribute [extern "lean_expr_mk_let"]    Expr.letE
attribute [extern "lean_expr_mk_lit"]    Expr.lit
attribute [extern "lean_expr_mk_mdata"]  Expr.mdata
attribute [extern "lean_expr_mk_proj"]   Expr.proj

-- deprecated Constructor
@[extern "lean_expr_local"]
constant Expr.local (n : Name) (pp : Name) (ty : Expr) (bi : BinderInfo) : Expr := default _

def mkApp (fn : Expr) (args : Array Expr) : Expr :=
args.foldl Expr.app fn

def mkCApp (fn : Name) (args : Array Expr) : Expr :=
mkApp (Expr.const fn []) args

namespace Expr
@[extern "lean_expr_hash"]
constant hash (n : @& Expr) : USize := default USize

instance : Hashable Expr := ⟨Expr.hash⟩

-- TODO: implement it in Lean
@[extern "lean_expr_dbg_to_string"]
constant dbgToString (e : @& Expr) : String := default String

@[extern "lean_expr_quick_lt"]
constant quickLt (a : @& Expr) (b : @& Expr) : Bool := default _

@[extern "lean_expr_lt"]
constant lt (a : @& Expr) (b : @& Expr) : Bool := default _

/- Return true iff `a` and `b` are alpha equivalent.
   Binder annotations are ignored. -/
@[extern "lean_expr_eqv"]
constant eqv (a : @& Expr) (b : @& Expr) : Bool := default _

instance : HasBeq Expr := ⟨Expr.eqv⟩

/- Return true iff `a` and `b` are equal.
   Binder names and annotations are taking into account. -/
@[extern "lean_expr_equal"]
constant equal (a : @& Expr) (b : @& Expr) : Bool := default _

@[extern "lean_expr_has_mvar"]
constant hasMVar (a : @& Expr) : Bool := default _

@[extern "lean_expr_has_fvar"]
constant hasFVar (a : @& Expr) : Bool := default _

def isSort : Expr → Bool
| Expr.sort _ => true
| _ => false

def isBVar : Expr → Bool
| bvar _ => true
| _ => false

def isMVar : Expr → Bool
| mvar _ => true
| _ => false

def isFVar : Expr → Bool
| fvar _ => true
| _ => false

def isApp : Expr → Bool
| app _ _ => true
| _ => false

def isConst : Expr → Bool
| const _ _ => true
| _ => false

def isForall : Expr → Bool
| forallE _ _ _ _ => true
| _ => false

def isLambda : Expr → Bool
| lam _ _ _ _ => true
| _ => false

def isBinding : Expr → Bool
| Expr.lam _ _ _ _ => true
| Expr.forallE _ _ _ _ => true
| _ => false

def isLet : Expr → Bool
| Expr.letE _ _ _ _ => true
| _ => false

def getAppFn : Expr → Expr
| Expr.app f a => getAppFn f
| e            => e

def getAppNumArgsAux : Expr → Nat → Nat
| Expr.app f a, n => getAppNumArgsAux f (n+1)
| e,            n => n

def getAppNumArgs (e : Expr) : Nat :=
getAppNumArgsAux e 0

private def getAppArgsAux : Expr → Array Expr → Nat → Array Expr
| Expr.app f a, as, i => getAppArgsAux f (as.set! i a) (i-1)
| _,            as, _ => as

@[inline] def getAppArgs (e : Expr) : Array Expr :=
let dummy := Expr.sort Level.zero;
let nargs := e.getAppNumArgs;
getAppArgsAux e (mkArray nargs dummy) (nargs-1)

private def getAppRevArgsAux : Expr → Array Expr → Array Expr
| Expr.app f a, as => getAppRevArgsAux f (as.push a)
| _,            as => as

@[inline] def getAppRevArgs (e : Expr) : Array Expr :=
getAppRevArgsAux e (Array.mkEmpty e.getAppNumArgs)

def isAppOf (e : Expr) (n : Name) : Bool :=
match e.getAppFn with
| Expr.const c _ => c == n
| _ => false

def isAppOfArity : Expr → Name → Nat → Bool
| Expr.const c _, n, 0   => c == n
| Expr.app f _,   n, a+1 => isAppOfArity f n a
| _,              _, _   => false

def constName : Expr → Name
| const n _ => n
| _         => panic! "constName called on non-const"

def constLevels : Expr → List Level
| const _ ls => ls
| _          => panic! "constLevels called on non-const"

def bvarIdx : Expr → Nat
| bvar idx => idx
| _ => panic! "bvarIdx called on non-bvar"

def fvarName : Expr → Name
| fvar n => n
| _ => panic! "fvarName called on non-fvar"

def bindingDomain : Expr → Expr
| Expr.forallE _ _ d _ => d
| Expr.lam _ _ d _ => d
| _ => panic! "binding expected"

def bindingBody : Expr → Expr
| Expr.forallE _ _ _ b => b
| Expr.lam _ _ _ b => b
| _ => panic! "binding expected"

/-- Instantiate the loose bound variables in `e` using `subst`.
    That is, a loose `Expr.bvar i` is replaced with `subst[i]`. -/
@[extern "lean_expr_instantiate"]
constant instantiate (e : Expr) (subst : Array Expr) : Expr := default _

@[extern "lean_expr_instantiate1"]
constant instantiate1 (e : Expr) (subst : Expr) : Expr := default _

/-- Similar to instantiate, but `Expr.bvar i` is replaced with `subst[subst.size - i - 1]` -/
@[extern "lean_expr_instantiate_rev"]
constant instantiateRev (e : Expr) (subst : Array Expr) : Expr := default _

/-- Replace free variables `xs` with loose bound variables. -/
@[extern "lean_expr_abstract"]
constant abstract (e : Expr) (xs : Array Expr) : Expr := default _

/-- Similar to `abstract`, but consider only the first `min n xs.size` entries in `xs`. -/
@[extern "lean_expr_abstract_range"]
constant abstractRange (e : Expr) (n : Nat) (xs : Array Expr) : Expr := default _

instance : HasToString Expr :=
⟨Expr.dbgToString⟩

-- TODO: should not use dbgToString, but constructors.
instance : HasRepr Expr :=
⟨Expr.dbgToString⟩

end Expr

def mkConst (n : Name) (ls : List Level := []) : Expr :=
Expr.const n ls

def mkBinApp (f a b : Expr) :=
Expr.app (Expr.app f a) b

def mkBinCApp (f : Name) (a b : Expr) :=
mkBinApp (mkConst f) a b

def mkDecIsTrue (pred proof : Expr) :=
mkBinApp (Expr.const `Decidable.isTrue []) pred proof

def mkDecIsFalse (pred proof : Expr) :=
mkBinApp (Expr.const `Decidable.isFalse []) pred proof

abbrev ExprMap (α : Type)  := HashMap Expr α
abbrev PersistentExprMap (α : Type) := PHashMap Expr α

/- Auxiliary type for forcing `==` to be structural equality for `Expr` -/
structure ExprStructEq :=
(val : Expr)

instance exprToExprStructEq : HasCoe Expr ExprStructEq := ⟨ExprStructEq.mk⟩

namespace ExprStructEq

protected def beq : ExprStructEq → ExprStructEq → Bool
| ⟨e₁⟩, ⟨e₂⟩ => Expr.equal e₁ e₂

protected def hash : ExprStructEq → USize
| ⟨e⟩ => e.hash

instance : Inhabited ExprStructEq := ⟨{ val := default _ }⟩
instance : HasBeq ExprStructEq := ⟨ExprStructEq.beq⟩
instance : Hashable ExprStructEq := ⟨ExprStructEq.hash⟩
instance : HasToString ExprStructEq := ⟨fun e => toString e.val⟩
instance : HasRepr ExprStructEq := ⟨fun e => repr e.val⟩

end ExprStructEq

abbrev ExprStructMap (α : Type) := HashMap ExprStructEq α
abbrev PersistentExprStructMap (α : Type) := PHashMap ExprStructEq α

namespace Expr

@[extern "lean_expr_update_app"]
def updateApp (e : Expr) (newFn : Expr) (newArg : Expr) (h : e.isApp = true) : Expr :=
Expr.app newFn newArg

@[inline] def updateApp! (e : Expr) (newFn : Expr) (newArg : Expr) : Expr :=
match e with
| Expr.app fn arg => updateApp (Expr.app fn arg) newFn newArg rfl
| _ => panic! "application expected"

end Expr

end Lean
