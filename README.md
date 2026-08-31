# Chain

Two habits, one X. A don't-break-the-chain tracker for working out and
publishing one piece of content a day, with mood alongside it.

Offline-first single-page app, Supabase Postgres behind it, an iPhone widget
and a native macOS nudge that both read the same database.

```
docs/                  the app — this is what GitHub Pages serves
  index.html           the whole thing: markup, styles, logic, fonts
  manifest.webmanifest add-to-home-screen metadata
  icon-*.png
schema.sql             table, policies, and the two read-only functions
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

## Rules

| | |
|---|---|
| **Full X** | Workout **and** content. Only these extend the chain. |
| **Half** | One of the two. A single stroke, and it breaks the chain. |
| **Rest day** | A deliberate off day. Bridges the chain without extending it. Capped at 4/month. |
| **Today** | A blank today never zeroes the number — the day isn't over. It only counts against you once tomorrow arrives. |
| **Backfill** | Today plus the 3 days behind it stay editable. Older days are locked. |

Both caps are adjustable in Settings.

The streak rules exist twice — in `docs/index.html` for the app and in
`schema.sql` for the widget and the nudge — so they're covered by matching
tests on both sides. Change one, change the other.

## Data model

One row per day in `days`:

| column | | |
|---|---|---|
| `d` | date | primary key, local calendar day |
| `w` | bool | workout |
| `c` | bool | content |
| `r` | bool | rest day |
| `m` | smallint | mood 1–5, null if unlogged |
| `n` | text | one-line note |
| `u` | bigint | client updated-at in ms — last write wins |

Local-first: every tap writes to the device immediately and syncs in the
background, so the app works with no signal and catches up later. Conflicts
resolve by `u`. **Export JSON** in the footer dumps the whole history.

## Two read-only functions

Both are `security definer` and callable with the publishable key, so the
widget and the nudge never reimplement the streak rules:

- `chain_status()` → today's flags plus the current streak
- `chain_nudge()` → a one-line nag, or an empty string when the day is done

## Setup

1. **Database** — paste `schema.sql` into the Supabase SQL editor and run it.
   Check it with `select * from chain_status();`
2. **Host** — GitHub Pages, serving from `main` / `docs`. Lives at <https://alex-rosier.github.io/chain/>.
3. **Devices** — open the Pages URL with `#k=<key>` appended, once per device,
   then Add to Home Screen (iOS) or Install as app (Chrome).
4. **Widget** — Scriptable, paste `chain-widget.js`, fill in the key and URL.
5. **Nudge** — `bash install-mac.command`, plus a Shortcuts time automation on
   the iPhone hitting `rpc/chain_nudge` and showing the result if non-empty.
