# Standard Base: Opening Day layout qualification

This checkpoint qualifies the free Primary Receiver layout for the **newly
started, archived Standard Base Season 2** route in the Linux Starter
player. It does not enable midseason structural changes or modify ordinary
legacy career files retroactively. The saved draft is not an installed
field. You can use the draft or keep the default before the first game;
the explicit choice stays locked for the season. The away opener never
uses the home layout. The draft and choice do not debit Club Bucks or
season Cash.

## Exact build and rendered result

The clean Godot 4.6.3 Linux Starter build used recovery source
`24c4a5ca7c963baca480ec0f96e06dfff0c43176`, tree
`b0d1851ff13381b0d4ff0d0ffb8a5e54a3f3e5a2`.
The unchanged reviewed-source, reviewed-package and no-save process
checks passed, including 1,246 reviewed pins and 3,061 raw package paths.
The official x86-64 runner (71,075,864 bytes) SHA-256 was
`2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0`.
The PCK (13,972,244 bytes) SHA-256 was
`cfdfada1406f5f0cc59a7a473cbbff12d8b7b70f88916d40dd7ea7a2f4448b50`.

In a disposable profile, the rendered player used the actual Start Next
control on a previously verified ordinary save, then drafted Val Morgan,
Gray West, Casey Rivers, and Ash Cole. The first Play presented Opening
Day Layout instead of starting a game. Cancel left the primary and backup
unchanged. The draft preview visibly showed the chair; Save Draft
persisted only the plan, then the review offered both choices. Use Saved
Layout returned to the clubhouse without launching; the locked Workshop
showed its read-only home-chair status. The subsequent Play opened the
away game at Commons Park. Quitting the unfinished game kept the exact
locked primary and backup. A new primary-only process reopened that
lock, with no new backup or temporary save.

The observed primary digests, in order, were:

- Before review: `9f5cccfefff4a59faa0b875fe3b16f50ce86a37f8009f0991e47dd06f976461a`.
- Saved workshop draft, not installed: `b0e13940ee3fbdd09ffd22fae2efd10443861ee9f09def36a3ebeec089d9f90b`.
- Chair locked: `c294a46aaf2dfbba4c93d04e43ae48a4738644dccca684fae14bda91be638933`.

An old unmarked Season 2 primary did not gain a choice. Its actual Play
opened Commons Park directly; unfinished Quit changed nothing. A
separate authenticated prior lock with a first-home fixture showed the
chair behind home from the live pitcher's view at Yard Club Field;
Quitting that unfinished game was also write-free. Keep Default was
visible in the rendered build and tested as a written lock and cold
reopen in the source rehearsal, not clicked to completion in this visual
pass. No visual test completed a game; no new round, Dynasty route,
higher league, macOS package or full beta is qualified by this document.
