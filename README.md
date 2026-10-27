# Dynamic Island for Mac

A notch app for the MacBook Pro: hover over the notch and it expands into a small black island with three tabs.

- **World Clock**: a dot-matrix 24-hour clock with your Mac's local time, plus up to 3 cities (New Delhi by default), each row showing the place on the left and its time on the right, all in dots.
- **Todo**: a quick local todo list, saved in `~/Library/Application Support/DynamicIsland/todos.json`.
- **Meetings**: the rest of today's meetings from Apple Calendar, with a countdown and a Join button for Zoom/Meet/Teams links.

Settings (cities, dot color, launch at login) are in the menu bar capsule icon or the gear in the island.

## Build & run

```bash
./scripts/build-app.sh          # builds build/DynamicIsland.app
open build/DynamicIsland.app
```

Debug helpers (run the binary directly):

```bash
build/DynamicIsland.app/Contents/MacOS/DynamicIsland --pin-expanded --tab meetings
```

## Test

```bash
swift test
```

The unit tests cover `IslandCore`: time zone offsets (including half-hour and DST), day rollover, city search, the dot-matrix glyphs, notch geometry, todo persistence, meeting filtering and countdowns, and video link detection.

### Manual checklist
- [ ] Collapsed island is invisible against the notch; menu bar clicks beside it still work
- [ ] Hover expands; moving away collapses after a short delay
- [ ] Clock ticks every second; New Delhi shows the right offset and "Tomorrow" after 20:30 local
- [ ] Add, complete and delete todos; they survive a relaunch
- [ ] First Meetings visit asks for Calendar access; Join opens the call
- [ ] Works over full-screen apps and on every Space; plugging in or unplugging a monitor adds or removes its island
- [ ] Sleep/wake and changing the system time zone update the clocks

## Layout

- `Sources/IslandCore`: pure logic, unit tested
- `Sources/DynamicIsland`: AppKit panel, hover handling, SwiftUI views, EventKit
- `Tests/IslandCoreTests`

## Credits

Tab and toolbar icons are from the [Streamline](https://www.streamlinehq.com) "Sharp" free set (watch-square-time, bullet-list, calendar-mark, arrow-reload-horizontal-2, cog), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Stroke width was reduced from 1.5 to 1.25.
