# Chain

Two habits, one X. A don't-break-the-chain tracker for working out and
publishing one piece of content a day — plus the journal, mood and optional
habits that let you work out *why* a day went the way it did.

Offline-first single-page app, Supabase Postgres behind it, an iPhone widget
and a native macOS nudge reading the same database.

```
docs/                  the app — this is what GitHub Pages serves
  index.html           the whole thing: markup, styles, logic, fonts
  manifest.webmanifest add-to-home-screen metadata
  icon-*.png
schema.sql             fresh-install schema: table, policies, functions
migrations/            changes to an existing database, newest last
chain-widget.js        iPhone home-screen widget (Scriptable)
install-mac.command    installs the 17:00 / 20:30 launchd nudge
chain.10m.sh           optional SwiftBar menu bar plugin
```

## No credentials in this repo

The Supabase **publishable key** is deliberately absent from every tracked
file. Each device gets it once and keeps it locally:

- **the app** — open it once with `#k=<key>` on the end of the URL. The app
  stores the key, strips the fragment out of the address bar, and never asks
  again on that device. The fragment is never sent to a server.
- **the widget** — paste the key into the one marked line inside Scriptable.
- **the Mac nudge** — `install-mac.command` prompts for it and writes it to
  `~/Library/Application Support/Chain/config`, mode 600, outside this repo.
  The SwiftBar plugin reads that same file.

## The rules

| | |
|---|---|
| **Full X** | Workout **and** content. Only these extend the chain. |
| **Half** | One of the two. A single stroke, and it breaks the chain. |
| **Rest day** | A deliberate off day. Bridges the chain without extending it. Capped at 4/month. |
| **Today** | A blank today never zeroes the number — the day isn't over. It only counts against you once tomorrow arrives. |

**Two locks, deliberately.** The chain locks after the backfill window
(3 days) — that's the accountability, and it's the point. The journal —
recap, mood, optional habits — never locks. A recap written on Sunday about
last Tuesday is exactly the material this exists to collect; refusing it
buys no honesty.

**Optional habits never touch the chain.** They have no "incomplete" state,
no red, no nagging; an unlogged one renders as nothing. They exist so you can
find out what actually correlates with a good day, and they're covered by a
test that asserts they can't move `stateOf()` or either streak.

## Views

- **Month / Year / All time** — the chain as a grid. The year has an
  **Ink / Mood** lens: the same twelve rows read either as chain marks or as
  a mood heatmap.
- **Log** — every day you wrote something, newest first, with its marks, mood
  and habits. This is the thing you read back.
- **Review** — the period's numbers, including *what moves the needle*: your
  full-X rate on days you did each optional habit against the days you
  didn't. A split only appears once both sides have 8+ days, so a 100% rate
  off two observations never shows up pretending to be a finding.
- **Copy week / Copy period** — the same data as markdown on your clipboard,
  led by a prompt asking for what happened, why the chain held or broke, what
  to change, and what to watch for. Paste into Claude. A month is about 4.5KB.

## Mood

Five steps on a sequential ink ramp — deliberately a *different* ink from the
marker, verified at ΔE 24.9 (18.2 under deuteranopia) against `#D33726`, so a
mood can never read as a chain mark. Lightness is strictly monotonic at about
0.10 per step in both themes.

Three channels carry the value, so it survives colour-blindness and a glance:
the arc gives direction, the fill gives intensity, the word names it.

## Data model

One row per day in `days`:

| column | | |
|---|---|---|
| `d` | date | primary key, local calendar day |
| `w` | bool | workout |
| `c` | bool | content |
| `r` | bool | rest day |
| `m` | smallint | mood 1–5, null if unlogged |
| `n` | text | the day's recap, free text |
| `x` | jsonb | optional habits, `{"meditate": true}` |
| `bio` | jsonb | reserved for Oura; unwired in the client |
| `u` | bigint | client updated-at in ms — last write wins |

The client declares these once, in `DAY_FIELDS`. `blank()`, `isEmpty()`, the
sync push (both the live and tombstone branches) and the sync pull are all
derived from it. They used to be four independent lists, and the pull asked
for `select=*` and then rebuilt a hand-written literal — so a column missing
from that one line was fetched and silently discarded while the push never
sent it. A field looked like it worked until a second device disagreed.

Local-first: every tap writes to the device immediately and syncs in the
background, so the app works with no signal and catches up later. **Export
JSON** dumps the whole history.

`x` values are plain booleans today. The shape takes `{"water": {"n": 5}}` or
`{"bed": {"at": "23:15"}}` later without another migration.

## Two read-only functions

Both `security definer` and callable with the publishable key, so the widget
and the nudge never reimplement the streak rules:

- `chain_status()` → today's flags plus the current streak
- `chain_nudge()` → a one-line nag, or an empty string when the day is done

Neither reads `x` or `bio`. The streak rules exist twice — in
`docs/index.html` for the app and in `schema.sql` for the widget and the
nudge — and both sides are tested against the same eight scenarios. Change
one, change the other.

## Migrations

`schema.sql` builds a database from scratch. It uses `create table if not
exists`, which is a **no-op** against an existing table and will not add
columns — an existing project takes changes from `migrations/` instead, newest
last. Every migration is written to be safe to run twice.

## Tests

```
node tests.js       # app logic: streaks, rest bridging, the two locks,
                    # midnight rollover, extras isolation, wire contract
node synctest.js    # two devices against a mock PostgREST: round-trips,
                    # offline queueing, conflicts, legacy-row shapes
node boottest.js    # first-run credentials, view switching, and no
                    # horizontal overflow at five widths in every view
node shots.js       # screenshots, phone and desktop, light and dark
```
