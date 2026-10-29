# clmb's mutators

Mutators for GulchCE / OpenCE: each folder is one mutator, a `mutator.toml`
and any files it names (docs/mutators.md, docs/addons.md in GulchCE).

| Folder | What it does |
| --- | --- |
| `accurized_ma5b` | The assault rifle with a 2x scope, a tighter spread and longer range (a stock mutator) |
| `big_head` | Heads drawn and hit at two and a half times their size (a stock mutator) |
| `revolved_plasma_rifle` | The plasma rifle as Combat Revolved has it (a stock mutator) |
| `falcon` | A UH-144 Falcon on Blood Gulch, from `bigass_open_v1.1.map` (an add-on) |

To play one, copy its folder into the data root's `mutators` folder. The
three stock mutators are already in the game: a copy of one, unchanged, is
played once, as the stock one. A changed copy keeps the id in its
`mutator.toml` and is played as `big_head@<its folder>` (docs/mutators.md,
"Two mutators with one id", in GulchCE).

`falcon/falcon.cevehicle` is built from `bigass_open_v1.1.map` with GulchCE's
`build/linux/cevehicle_build` (the command is in `falcon/mutator.toml`). The
Falcon is a fan asset without a licence.

## The index

`mutator-index.toml` lists the mutators and their files' sizes and SHA-256
checksums, for a game given this repository's link (docs/mutators.md,
"Mutator repositories", in GulchCE). Write it again after changing a mutator:

    python <GulchCE>/tools/mutator_index.py .
