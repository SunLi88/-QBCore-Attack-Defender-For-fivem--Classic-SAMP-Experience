# Attack & Defend — v2.0

Clean rewrite. No leftover bugs from v1. Full English.

## Requirements
- QBCore framework
- oxmysql

## Install
1. Drop the `attackdefend` folder into your `resources/` directory.
2. Import `ad_stats.sql` into your database.
3. Add `ensure attackdefend` to your `server.cfg`.
4. Configure `shared/config.lua` to your liking.

## Admin Commands
| Command | Description |
|---|---|
| `/adm start [id]` | Start a match on base ID |
| `/adm stop`       | Stop the current match |
| `/adm map [id]`   | Switch map mid-session |
| `/adm kick [id]`  | Remove a player from the match |
| `/adm bases`      | List all available base IDs |
| `/adm status`     | Show current game state |

## Player Controls
| Key | Action |
|---|---|
| `F5` | Open / close the team menu |
| `Q` / `E` | Previous / next player while spectating |

## Key Fixes vs v1
- Event names unified (all prefixed `ad:` — no mixed naming)
- `ON DUPLICATE KEY UPDATE` in SQL — single upsert, no SELECT + branch
- Capture zone entered automatically when attacker walks in (no key press)
- `SetTimeout` used for intermission/match-end instead of nested `CreateThread` + `Wait` loops that could race
- Respawn to lobby only sent server-side after round end — no duplicate individual triggers
- OOB reset properly when leaving/match ends (no false-positives on spawn)
- Spawn protection cleared via timer check, not a `Wait` thread that could stack
- Test NPC disabled by default (`Config.TestNPC.enabled = false`)
- All UI text in English
