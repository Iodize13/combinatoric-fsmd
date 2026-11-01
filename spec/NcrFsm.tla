---------------------------- MODULE NcrFsm ----------------------------
(* Control-level model of rtl/ncr_core.vhd. Each muldiv operation is abstracted
   to one step (MUL = START+WAIT for MULTU, DIV = START+WAIT for DIVHL); muldiv
   itself is proven by formal/muldiv.sby. *)
EXTENDS Naturals

CONSTANTS MaxN, Width

RECURSIVE Fact(_)
Fact(x) == IF x = 0 THEN 1 ELSE x * Fact(x - 1)
Binom(a, b) == IF b > a THEN 0 ELSE Fact(a) \div (Fact(b) * Fact(a - b))
Min(a, b) == IF a < b THEN a ELSE b

States == {"IDLE", "INIT", "CHECK", "MUL", "DIV", "FIN"}

VARIABLES state, n, r, nmr, k, i, res, prod, ovf

vars == <<state, n, r, nmr, k, i, res, prod, ovf>>

MaxResult == 2 ^ Width - 1

Init ==
  /\ state = "IDLE"
  /\ n = 0 /\ r = 0 /\ nmr = 0 /\ k = 0 /\ i = 0 /\ res = 0 /\ prod = 0
  /\ ovf = FALSE

Start ==
  /\ state = "IDLE"
  /\ \E a \in 0..MaxN, b \in 0..(MaxN + 1) :
       /\ n' = a /\ r' = b
  /\ state' = "INIT"
  /\ ovf' = FALSE
  /\ UNCHANGED <<nmr, k, i, res, prod>>

InitStep ==
  /\ state = "INIT"
  /\ IF r > n
       THEN /\ res' = 0 /\ state' = "FIN"
            /\ UNCHANGED <<nmr, k, i>>
       ELSE /\ k' = Min(r, n - r)
            /\ nmr' = n - Min(r, n - r)
            /\ res' = 1 /\ i' = 1
            /\ state' = "CHECK"
  /\ UNCHANGED <<n, r, prod, ovf>>

Check ==
  /\ state = "CHECK"
  /\ state' = IF i > k THEN "FIN" ELSE "MUL"
  /\ UNCHANGED <<n, r, nmr, k, i, res, prod, ovf>>

Mul ==
  /\ state = "MUL"
  /\ prod' = res * (nmr + i)
  /\ state' = "DIV"
  /\ UNCHANGED <<n, r, nmr, k, i, res, ovf>>

\* DIVHL refuses when HI >= i (quotient would not fit): ovf is set, res
\* saturates to all ones, and the loop stops.
Div ==
  /\ state = "DIV"
  /\ IF prod \div (2 ^ Width) >= i
       THEN /\ ovf' = TRUE
            /\ res' = MaxResult
            /\ state' = "FIN"
            /\ UNCHANGED i
       ELSE /\ ovf' = ovf
            /\ res' = prod \div i
            /\ i' = i + 1
            /\ state' = "CHECK"
  /\ UNCHANGED <<n, r, nmr, k, prod>>

Fin ==
  /\ state = "FIN"
  /\ state' = "IDLE"
  /\ UNCHANGED <<n, r, nmr, k, i, res, prod, ovf>>

Next == Start \/ InitStep \/ Check \/ Mul \/ Div \/ Fin

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ---- Properties ----

TypeOK == state \in States

\* Loop invariant: after i-1 iterations without overflow, res = C(nmr + i - 1, i - 1).
LoopInv == (state = "CHECK" /\ ~ovf) => res = Binom(nmr + i - 1, i - 1)

\* The division in DIV never leaves a remainder: integer arithmetic is exact.
ExactDivision == (state = "DIV" /\ ~ovf) => prod % i = 0

\* Contract at FIN: the exact C(n, r) when it fits in Width bits,
\* otherwise ovf with res saturated to all ones.
FinCorrect ==
  state = "FIN" =>
    IF Binom(n, r) > MaxResult
      THEN ovf /\ res = MaxResult
      ELSE ~ovf /\ res = Binom(n, r)

\* Overflow stops the loop: no further multiply is started once ovf is set.
StopOnOvf == ovf => state \notin {"MUL", "DIV"}

\* Every started computation finishes.
Terminates == (state = "INIT") ~> (state = "FIN")
=============================================================================
