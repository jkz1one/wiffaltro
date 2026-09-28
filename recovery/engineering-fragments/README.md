# Partial engineering recovery, September 28, 2026

These source texts were recovered from the literal file-writing commands still visible in
this conversation after workspace maintenance deleted the engineering checkout. They include
subsequent visible edits. Formatting may differ from the lost gdformat output. They are not
a recovered complete checkout and have not been rerun successfully against this baseline.

The .txt suffix prevents Godot from importing incomplete modules into the surviving game.
The runner and test depend on missing seasonal implementation, including SeasonDoubleheader,
seasonal pitching profiles, final_sponsors_test.gd and prior MatchLabSupport changes.
The remaining September 26–28 engineering has not been recovered.

The runner's original integration also added an optional `autonomous: bool = false` parameter
to MatchLabSupport.consider_ai_pitching_change and assign_ai_fielder_anchor. Their human-side
guards became `(not autonomous and not lab._player_is_batting())`; existing legal-substitution
and null-state guards remained. These descriptions are not substitutes for the lost files.

The original verification entry was named `autonomous-match`, ran the test scene at
`--fixed-fps 60`, and required `Wiffaltro autonomous match checks passed:`. Historical reports
of passing verification do not establish that these fragments run on this restored checkout.
