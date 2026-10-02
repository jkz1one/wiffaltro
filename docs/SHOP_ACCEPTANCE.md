# Shop and Equipped hands-on review

**Human visual/feel acceptance: pending.** All 25 Gear and 35 sponsors, five tactical supplies, three learned abilities and one transformation are implemented. This walkthrough provides a review baseline for the completed shop content. Whole-project completion remains approximately 75%; it is not release readiness.

## Launch a separate review season

From the engineering checkout, run:

```bash
python3 tools/prepare_shop_review.py
```

Import the printed `project.godot` in **Godot 4.7.2** and press **F5**. The copied project has a fresh save/settings profile. Reopen that same copy to resume its review season. Running the preparation command again creates another fresh profile. It refuses existing output directories; optional `--output <new-directory>` selects the destination.

Runtime source/content is copied unchanged. Only the copied application's title and save-profile settings differ. The manifest records runtime hashes, source commit and whether the checkout contained uncommitted changes. It does not copy saves, grant unlocks, alter prices or populate artificial shop stock. The production project and regular save remain unchanged.

## Walk through the real flow

1. Choose **NEW WORKING SEASON**, accept its Working-calibration explanation, then **START TRYOUTS**. Draft four players and use the lineup/scouting flow to start the first game. Mouse aims; left click handles Contact/pitching and right click handles Power. Follow the on-screen batter/release prompts. Esc opens pause/settings.
2. Complete the game and open **SEASON SHOP**. Read an offer's effect, price and resulting Cash. Inspect its final review, Cancel, and check that Cash/ownership did not change. Buy an affordable Gear or sponsor when available. Initial earned content can vary; do not expect all locked items in a fresh season.
3. Open the centered **EQUIPPED** button. Browse Gear, Sponsors, Supplies and Abilities; read effects, status and any refund action. Open a sale review, Cancel, then check the same owned copy remains. Sell a paid copy if desired: Cash should update immediately, the sold item should leave ownership, and shop offers should stay fixed.
4. Close Equipped and start the next game. Open it from the same centered entry, inspect effects, and close it. Play should resume without an accidental swing/pitch. If a paid item remains, sell it during a plate appearance: the refund saves immediately, while its current effect stays listed until the next batter. At that boundary the sold effect retires. Sold sponsors earn no postgame income.
5. Quit and reopen the **same review copy**. Confirm the saved refund and ownership removal. An unfinished game restarts; the sale must remain saved. Try normal size and a 700×400 shop client, keyboard navigation, mouse wheel and controller if available.

## Feedback needed

- Are item effects, prices, Cash outcomes and refund actions readable without awkward scrolling?
- Does Equipped open/close comfortably in the same place during shop and play, with clear pause/resume behavior?
- Which confirmation, purchase, replacement or sale interaction feels confusing or slow?

Report the screen/item, window size and input device for any problem. No human acceptance is inferred from automated checks or these screenshots.

## Primary references and scope

The [official Balatro press kit](https://www.playbalatro.com/press-kit/) supplied shop/game/modal references for stable inventory access, adjacent prices/actions and a clear return path; no reference artwork is copied. [Godot's AcceptDialog documentation](https://docs.godotengine.org/en/stable/classes/class_acceptdialog.html) specifies its dialog button-height theme setting and default exclusive modal behavior. [Godot's data-path documentation](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html) specifies custom application save directories used by the review launcher.

The automated evidence and native screenshots are recorded in [VERIFICATION](VERIFICATION.md) and [SHOP_UI_REVIEW](SHOP_UI_REVIEW.md). Native review uses the actual Godot renderer with Mesa software graphics and Dummy audio. It checks layout and interactions, but cannot establish hardware performance, audio, camera comfort or subjective response feel. Historical intermittent suite early exits and the final cohesive whole-game UI pass remain open.
