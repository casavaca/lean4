/-
Copyright (c) 2022 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import Lean.Compiler.LCNF.PassManager
import Lean.Compiler.LCNF.PullLetDecls
import Lean.Compiler.LCNF.CSE
import Lean.Compiler.LCNF.Simp
import Lean.Compiler.LCNF.PullFunDecls
import Lean.Compiler.LCNF.ReduceJpArity
import Lean.Compiler.LCNF.JoinPoints
import Lean.Compiler.LCNF.Specialize
import Lean.Compiler.LCNF.PhaseExt

namespace Lean.Compiler.LCNF

@[cpass] def builtin : PassInstaller :=
  .append #[
    pullInstances,
    cse,
    simp,
    pullFunDecls,
    findJoinPoints,
    reduceJpArity,
    simp { etaPoly := true, inlinePartial := true, implementedBy := true } (occurrence := 1),
    specialize,
    simp (occurrence := 2),
    saveBase -- End of base phase
  ]

end Lean.Compiler.LCNF
