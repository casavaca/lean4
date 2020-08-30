new_frontend

theorem ex1 (x : Nat) (y : { v // v > x }) (z : Nat) : Nat :=
by {
  clear y x;
  exact z
}

theorem ex2 (x : Nat) (y : { v // v > x }) (z : Nat) : Nat :=
by {
  clear x y;
  exact z
}

theorem ex3 (x y z : Nat) (h₁ : x = y) (h₂ : z = y) : x = z :=
by {
  have y = z from h₂.symm;
  apply Eq.trans;
  exact h₁;
  assumption
}

theorem ex4 (x y z : Nat) (h₁ : x = y) (h₂ : z = y) : x = z :=
by {
  let h₃ : y = z := h₂.symm;
  apply Eq.trans;
  exact h₁;
  exact h₃
}

theorem ex5 (x y z : Nat) (h₁ : x = y) (h₂ : z = y) : x = z :=
by {
  let! h₃ : y = z := h₂.symm;
  apply Eq.trans;
  exact h₁;
  exact h₃
}

theorem ex6 (x y z : Nat) (h₁ : x = y) (h₂ : z = y) : id (x + 0 = z) :=
by {
  show x = z;
  let! h₃ : y = z := h₂.symm;
  apply Eq.trans;
  exact h₁;
  exact h₃
}
