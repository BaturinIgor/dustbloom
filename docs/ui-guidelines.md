# UI guidelines

Rules every DUSTBLOOM screen follows. They come from Apple's Human Interface
Guidelines, Unity's mobile UI guide and how top casual farm/strategy games
(Hay Day, Township, Clash of Clans) lay out their screens.

## Layout
- The farm is the main screen. The HUD shows at most: coins, level, premium
  currency, and up to four round action buttons. Everything else opens on tap.
- Primary actions live in the bottom third (thumb zone). Top corners are for
  read-only status (coins, level, online dot).
- Respect the safe area: nothing interactive under the Dynamic Island or the
  home indicator; 16 pt side margins.
- Everything sits on a grid of 4 pt. Panels, slots and buttons in one row have
  equal size and equal gaps, and the row is centred. Check symmetry on every
  screenshot before showing it.

## Touch
- Minimum touch target 44×44 pt, 56 pt for frequent actions.
- At least 8 pt between targets.
- Every tap answers within 100 ms: sound, haptic, a squash on the button.
- Long actions (selling 20 crops) use one tap per batch or hold-to-repeat,
  never 20 separate confirmations.

## Screens
- Secondary screens are bottom sheets over the farm (the farm stays visible),
  closed by swipe down or a tap outside. Tabs on top for related screens
  (Barn / Workshop / Raids).
- Cost rows show "have / need" with the item icon; enough is ink, not enough is
  red. A disabled button says why ("Need 3 more Dustwheat").
- Timers show a progress bar plus the time left; finished things wear a badge
  on their HUD button.
- Confirm only what cannot be undone or spends premium currency.

## Feedback and reward
- Gains fly to where they are stored (crops to the barn button, coins to the
  coin counter), then the counter bumps.
- Wins get a short celebration (sound, sparkle, numbers counting up); losses
  get a clear reason and a next step ("Build 2 more Pumpkin Brutes").
- Red dot badges only for things the player can act on now.

## Text
- All strings come from localisation files; layouts must survive German and
  Russian strings 40% longer than English.
- Numbers use the pixel font; names and sentences use a readable font at 15 pt
  or larger.
