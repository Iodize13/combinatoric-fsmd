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

VARIABLES state, n, r, nmr, k, i, res, prod

vars == <<state, n, r, nmr, k, i, res, prod>>

Init ==
  /\ state = "IDLE"
  /\ n = 0 /\ r = 0 /\ nmr = 0 /\ k = 0 /\ i = 0 /\ res = 0 /\ prod = 0

Start ==
  /\ state = "IDLE"
  /\ \E a \in 0..MaxN, b \in 0..(MaxN + 1) :
       /\ n' = a /\ r' = b
  /\ state' = "INIT"
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
  /\ UNCHANGED <<n, r, prod>>

Check ==
  /\ state = "CHECK"
  /\ state' = IF i > k THEN "FIN" ELSE "MUL"
  /\ UNCHANGED <<n, r, nmr, k, i, res, prod>>

Mul ==
  /\ state = "MUL"
  /\ prod' = res * (nmr + i)
  /\ state' = "DIV"
  /\ UNCHANGED <<n, r, nmr, k, i, res>>

Div ==
  /\ state = "DIV"
  /\ res' = prod \div i
  /\ i' = i + 1
  /\ state' = "CHECK"
  /\ UNCHANGED <<n, r, nmr, k, prod>>

Fin ==
  /\ state = "FIN"
  /\ state' = "IDLE"
  /\ UNCHANGED <<n, r, nmr, k, i, res, prod>>

Next == Start \/ InitStep \/ Check \/ Mul \/ Div \/ Fin

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ---- Properties ----

TypeOK == state \in States

\* Loop invariant: after i-1 iterations, res = C(nmr + i - 1, i - 1).
LoopInv == state = "CHECK" => res = Binom(nmr + i - 1, i - 1)

\* The division in DIV never leaves a remainder: integer arithmetic is exact.
ExactDivision == state = "DIV" => prod % i = 0

\* DIVHL precondition: HI < i, i.e. the quotient fits in Width bits.
NoQuotOverflow == state = "DIV" => prod \div (2 ^ Width) < i

\* When FIN is reached the answer is C(n, r).
FinCorrect == state = "FIN" => res = Binom(n, r)

\* Every started computation finishes.
Terminates == (state = "INIT") ~> (state = "FIN")
=============================================================================
