#loop-interpretor

>March/April 2005 - John B. Silvestri

>loopint{,4}.pl - an interpreter for Stathis Zachos' loop language

About these interpreters:
These interpreters were written to test out code in an otherwise theoretical
language, 'loop,' as presented by Stathis Zachos (his creation?) in a Theory
of Computation course taught at Brooklyn College.

This may have been used as an example when introducing the ever fun
pumping lemma:

∀L: regular ∃n∈ℕ:∀z∈L |z|≥n: ∃uvw∈∑*: [z=uvw ∧ |uv|≤=n ∧ |v|≥1 ∧ ∀i∈ℕ:uvⁱw∈L]

Regardless, this code and some examples of loop code may be found in here,
silly comments and all.  At some point, I might give it another read and try
to clean parts up - maybe a 'loopint5.pl' is due?
