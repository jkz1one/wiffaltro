# Season camera research and revised direction

Research date: 2026-09-23. Status: implemented design basis; see `SEASON_CAMERA_AI_REVISION.md` for validation. Rendered comfort review remains open.

## Evidence

1. [John DeMarsico interview, Bright Wall/Dark Room, March 2024](https://www.brightwalldarkroom.com/2024/03/26/john-demarsico-interview/). DeMarsico places creative flourishes largely in the intervals around live action. Cameras have situation-specific assignments; cuts should wait for their moment. The useful lesson is purposeful composition and anticipation.
2. [John DeMarsico interview, Awful Announcing, June 2025](https://awfulannouncing.com/mlb/sny-director-john-demarsico-baseball-cinematic-experience-mets.html). He explicitly describes the conventional center-field pitch shot followed by a 180-degree cut to high home for contact. This is evidence of broadcast practice, not evidence that the same cut suits interactive defense.
3. [Florida State Seminole Productions camera assignments](https://sempro.cci.fsu.edu/training/diamond-sports/). High-home coverage frames the bases and follows the ball. The center-field assignment includes widening for a ball up the middle. Different positions serve different coverage needs.
4. [Eric Undersander, Game Developer, September 2011, printed pages 7 onward](https://media.gdcvault.com/GD_Mag_Archives/GDM_September_2011.pdf). The Reckoning camera implementation addresses smooth acceleration, group framing, and obstacles. Its failed simulated cameraman produced looping paths; simply making a camera travel physically does not guarantee a good shot.

These are interviews, operating instructions, and an implementation account. This pass does not constitute a frame-by-frame study of Mets broadcast footage. The earlier user recording was inspected separately; no new recording of the reported regression was supplied.

## Application to Wiffaltro

The following is our design inference, not a prescription from the sources. The player needs to judge ball travel and fielding opportunities while retaining a sense of the field. A full broadcast crew can switch among prepared viewpoints; our moving camera must also preserve playable spatial orientation.

Contact should initiate a coverage decision, not automatically select a reverse angle. No rule requires the view to lock after release. Movement remains available whenever it improves coverage.

| Play | Initial response | Further movement |
| --- | --- | --- |
| Soft contact fielded before Single | Open the existing composition enough to include the ball and fielding area | Settle as the play resolves; no compulsory orbit |
| Grounder, including beyond Double | Pull back and gain modest height; use a lateral offset when needed | Follow the ground corridor without treating a scoring-line crossing as a shot-change trigger |
| Hard low liner | Widen promptly to preserve reaction space | Use a controlled side move if framing requires it; speed alone does not justify reversal |
| Deep airborne hit | Open framing based on estimated carry, direction, and remaining flight time | Gradually establish a wider elevated side view when there is time and a coverage benefit |
| Short high popup | Add vertical framing while retaining nearby field landmarks | Height alone must not trigger the deep-hit treatment |

Estimate flight from currently observable ball state and the game's physics. Do not use the eventual scoring result to choose the shot. Smooth revisions to that estimate so bounces or small changes cannot switch the selected side repeatedly.

Separate framing from travel: determine which subjects and ground area must fit, then select camera position, aim, and field of view. Prefer moving back and sideways before large rotation when this preserves those subjects. A slow 180-degree orbit can still be disorienting; lowering interpolation speed alone is insufficient. Keep the chosen side stable during a play unless visibility genuinely requires changing it.

## Defects identified in the previous pass

- `prepare_ball_in_play` schedules an immediate transform replacement at contact. This bypasses interpolation.
- Visibility recovery can also replace the transform abruptly. Fixing only the contact path will leave another source of jumps.
- Coverage relies primarily on the ball, rather than the relationship between ball, fielding area, and ground landmarks.
- Earlier motion checks omitted the initial transition frame. Their passing result did not establish a comfortable entry into defense.

## Validation before calling it improved

Use actual simulated trajectories for soft contact, straight and angled grounders, low liners, short popups, and deep fly balls. Include plays resolved before Single and rollers passing Double. Exercise both sides and scenery occlusion.

Measure from the last pitching frame through contact and resolution: camera displacement, angular change, acceleration, ball screen position, subject visibility, and unintended side changes. Test different frame rates. Do not invent a universal comfort threshold from these sources; tune limits against rendered playback.

Review clips at normal speed, especially contact and early fielding. Numerical visibility tests are necessary but cannot certify comfort. If rendering is unavailable, report that limitation and leave perceptual validation open.

The pitching-AI audit and implementation results are recorded separately in `SEASON_CAMERA_AI_REVISION.md`. Camera research itself does not validate batting balance.

## Additional reference: baseball video games

User requested this as additional knowledge, not as an instruction to copy another game's camera.

| Reference | Documented behavior | Useful question for our design |
| --- | --- | --- |
| MLB 15 The Show, official Japanese manual, Fielding settings | Separate Dynamic, Medium, High, and Broadcast defensive views. Dynamic adapts to ball position; Broadcast uses television-like placement. This documents that edition, not current-edition timing or implementation. | Are we deliberately choosing playable coverage, presentation, or a blend for each situation? |
| Super Mega Baseball 4, EA staff gameplay notes | A line-drive camera was added specifically to help judge whether to jump. | Does a camera move make the player's next decision easier? |
| Super Mega Baseball 4, Update 3 notes | Use of that camera was subsequently narrowed toward liners at infielders where it helps judge a jump. | Have we made a useful special-case angle fire too broadly? |

Sources:

- [MLB 15 official manual, Gameplay Options 2](https://playstation-doc.net/j/theshow15/ps3/option2.html), IN-PLAY VIEW DEFENSE. Japanese description translated for this summary.
- [EA staff: Ballpark Notes, Gameplay On and Off-Field](https://forums.ea.com/discussions/other-ea-games-en/ballpark-notes---gameplay-on-and-off-field/10925575), On-field Improvements.
- [EA: Update 3 patch notes](https://www.ea.com/news/update-3-patch-notes). Camera change available in indexed official search text; direct page fetch returned 404 during this pass.

Inference: choose coverage around the fielding decision and restrict special angles to the situations they help. Neither source establishes exact cut delay, pan speed, dolly path, or a universally comfortable angle. No comparative gameplay footage was inspected in this pass; frame-by-frame comparisons of short grounders, low liners, and deep flies remain open. Do not present source descriptions as visual observations.
