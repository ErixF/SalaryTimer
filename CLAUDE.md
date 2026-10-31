# SalaryTimer ("Touch Fish")

iOS app that meters how much you earn per second. SwiftUI, SwiftData, ActivityKit. Both the app and the widget extension `TouchFish` (Live Activity) target **iOS 27.1** (raised from 26.0 in the iPhone Duo round) (Liquid Glass used directly, no fallbacks). Tabs: **Meter / Records / Settings**.

## Architecture

| File | Role |
|---|---|
| `SalaryTimer/SalaryTimerStore.swift` | **Meter engine.** `MeterState` (idle/running/paused), segment math, persistence, Live Activity lifecycle (start/update/end, 15s refresh while running, reconcile on launch). `RateCalculator` (all rate math). `ProfileKeys` (AppStorage keys, incl. `currencySymbol`, `sessionGoal`). `SessionGoal` (parses the optional goal). |
| `SalaryTimer/SalaryTimerApp.swift` | App entry, `RootTabView`, `AmbientBackground` (3-state meter backdrop), `ScreenBackground` + `GroupedCard` + `RowBackground` (Records/Settings styling), `ToastView` (shared glass toast), `Color(hex:)`. |
| `SalaryTimer/ContentView.swift` | Meter tab: portrait layout, `LandscapeMeter`, `StateChip` (tinted glass), `StatTile`, `GoalCard`, toast, hidden reset, `contentCard` modifier. |
| `SalaryTimer/SettingsView.swift` | Settings tab (gear icon; was "Profile"). Apple Settings style: `NavigationSplitView` root list (icon rows Currency / Income / Deductions / Session Goal with current values, Alternative Look toggle) → detail `Form` pages via `paneForm`. Wide screens show list + page side by side (starts on Currency); phones push. `isSheet` adds an X. |
| `SalaryTimer/SessionLogView.swift` | Records: All Records (grouping, index bar, collapse, summary) + Top 10. `SessionFormatters` (durations, dates, money via `Money`). |
| `SalaryTimer/DataSet.swift` | `SalarySession` SwiftData model. |
| `SalaryTimer/DebugSampleData.swift` | `#if DEBUG` only: add/remove random sample records (ids tracked in `debug.sampleRecordIDs`, so removal never touches real sessions). Triggered from Hidden Tools. |
| `Shared/` | Compiled into **both** targets (synchronized group listed in each target). `SalaryTimerAttributes` (Live Activity data: timer start, amount anchor, rate, `pausedAt`, `currencySymbol`, `goalAmount`), `Money` (currency formatting). Put anything the app and widget both need here. |
| `TouchFish/SalaryTimerLiveActivity.swift` | Lock Screen / Dynamic Island UI. `TouchFish/SalaryTimerBundle.swift` registers only the Live Activity. |

New files are picked up automatically (file-system synchronized groups). Swift 5 language mode, no default MainActor isolation.

## Core rules (decided with Eric — don't change without asking)

### Meter
- **State machine:** Idle → Start. Running → Pause only. Paused → Resume + "Archive & Reset" (saves record, back to Idle). No archiving while running.
- **Segments:** each Start/Resume captures the Settings rate; each Pause locks in time/net/gross. Rate edits while paused apply only from the next Resume. Never compute `elapsed × current rate` for a whole session.
- **Timekeeping is timestamp-based** (no `Timer`); views tick via `TimelineView(.periodic(by: 1))`. Session state is persisted to UserDefaults (`meter.*` keys) on every transition and restored on launch, so it survives app kill.
- **Button colors** (portrait and landscape): Start blue, Pause amber, Resume green (all `.glassProminent`); Archive & Reset plain glass. Landscape state label uses the state color (Ready blue, Running green, Paused amber).
- **Controls** sit at a fixed height in every state; first-use hint lives in a fixed 34pt slot above them (`@AppStorage("meter.hasArchived")`, shown in Paused until first archive).
- **Detail card** shows "Started HH:MM:SS". **Goal card** (only when a goal is set) sits under the Today so far / Last session tiles: "62% of $400" or "✓ Reached", bar tinted by state.
- **Hidden Tools:** 10 quick taps on the big amount (any layout except the black landscape view) open a sheet; it closes only via its X. Debug builds only: Show First-Use Hint / Mark as Returning User (`meter.hasArchived`), Add / Remove Sample Records. Always: Reset App (confirm alert; saves any metered time, resets meter, clears Settings values, keeps Records). The sheet only closes via Done (`interactiveDismissDisabled`, so extra fast taps don't dismiss it); actions show a green ✓ confirmation line instead of closing.
- **Landscape (black minimal meter):** only when `verticalSizeClass == .compact` (phones in landscape, Duo outer landscape); the tab bar hides there too. Regular-height sizes (Duo inner display, iPad) never get it. No "Go get an iPhone" anymore.
- Portrait Meter caps Dynamic Type at XXX Large (beyond that, controls slide under the tab bar).

### Settings
- Native `Form` sections, each with a short footer: **Currency** (symbol menu) → **Income** (Income Type menu + matching fields; footer "Changes only affect upcoming sessions.") → **Your Rate Calculated** (green-tinted rows, bold green total) → **Deductions** → **Session Goal**. Values right-aligned with gray units, no boxed fields, headers without "(optional)" (placeholder says Optional).
- Inputs locked while running, editable while paused (gray status line at top). No "Saved" toast — values auto-save. Focused field is scrolled to center so the keyboard's floating Done button doesn't cover it; 72pt bottom content margin clears the tab bar.
- Deductions is one optional % (blank = 0% = "Gross"; entered = "Take-home"), clamped 0–100. Hourly and Monthly values are stored separately. Existing `profile.*` keys must stay (user data).
- **Currency symbol:** `$ € £ ¥ ₹ ₩ ₽ ₺ ₱ ฿ R$ kr CHF`, no custom. Always before the number (letter symbols get a space: `kr 12.50`). Label only — no conversion; changing it relabels every amount including old records. All money goes through `Money.string`.
- **Session goal:** optional `profile.sessionGoal`. Blank = open goal: no card, no bar anywhere.

### Records
- **Model:** `unitPrice` = session average net/sec; `startDate` and `grossEarned` are optional (nil for pre-2.3 records). Changing deductions never rewrites saved records.
- **Grouping:** Today / Yesterday / per day for 30 days, then per month. Section index labels: day number, or short month (`Sep`, `Sep ’25` outside current year). Collapsing hides rows only — header and index entry stay.
- **Summary** cards sit above the list (not in its scroll area), so rows never pass behind them; the list's top 24pt is a gradient mask (extended past the bottom so rows still scroll under the tab bar) (`topFade()`, also used on Top 10 under the segmented control) so rows fade out before reaching what's above. List has a 30pt trailing content margin to clear the index bar. Cards: Total earned / Total time (same format as rows: `3min 6s`, `1h 42min`) / Sessions. **Top 10:** `medal.fill` gold/silver/bronze for 1–3, plain numbers after, no "Personal best" chip; "Top 10 by earnings, across all sessions." is the section footer under the rows.

### Live Activity
- Moving parts are only Apple's built-in timer views: the elapsed **timer** and a timer-driven `ProgressView` **goal bar** ($0 → goal over the whole session; hidden without a goal; green ✓ beside "Goal $X" once reached as of the last app update).
- **Lock Screen / expanded:** RUNNING/PAUSED chip + rate (`≈ $50.00/hr · $0.0139/sec`), timer as hero, goal bar. System background, 14pt margins.
- **Compact:** live timer left, state-colored capsule with whole-unit rate (`$50/hr`) right. **Minimal:** currency symbol in a state-colored circle. Keyline follows state. Running green, paused amber.
- The amount itself can't tick on the Lock Screen (see gotchas); it only updates when the app pushes (15s loop while the app runs, plus on start/pause/resume). No push server — decided.

### Visual language
- SF Pro family only; amount and title use SF Pro Rounded. Glass is for controls and status only (buttons, toasts, landscape button, tab bar, the Meter state chip as tinted glass); content cards are flat translucent fills. Confirmations ("Saved to Records") use the shared `ToastView`, placed outside any `NavigationStack` so it sits just below the Dynamic Island.
- Idle blue, Running green, Paused dim green + amber chip. App follows system light/dark (landscape meter is always black). Records and Settings use the navy `ScreenBackground` in dark mode.

## Known gotchas

- **Custom `FormatStyle`s in `Text(.currentDate, format:)` render as grey placeholder bars in Live Activities** (tested on device). Only Apple's built-in date/timer styles tick on their own. A "next dollar" progress bar was also tried and dropped: once full it can't restart without the app.
- **Xcode Previews crash** (iOS 27.1 / iPhone Duo sim) on a `List` with rows: "Could not cast UICollectionViewCell to SwiftUI.AnyListCollectionViewCell" from `PreviewsInjection`. Real app is fine. Records `#Preview` is intentionally empty — verify populated Records on device (use the debug sample data). The Settings `Form` previews fine. Live Activity previews occasionally fail to snapshot; retry once, then check on device.
- Preview thunks are stricter than the real build: button action closures passed through helpers need `@MainActor () -> Void`, and `Button("…", action: method)` can be ambiguous — use a closure.
- After deleting a file, the first build may fail with "Build input file cannot be found"; just build again.
- After editing `project.pbxproj` outside Xcode (e.g. the `Shared/` group), the **live editor checker** can show false errors like "Cannot find 'Money' in scope" while the real build succeeds. Fix: Clean Build Folder, or close and reopen the project. Check the issue's origin (`live` vs build) before changing code.
- `git add` with one missing path aborts the whole add — verify commit contents with `git show --stat` before pushing.
- The default preview device is iPhone Duo; use the `Display: Inner/Outer` and `Orientation` variants to check foldable/landscape.

## Progress

- **2.3 redesign (done, Oct 2026):** state machine, persisted sessions, segment math; Meter, landscape, Records and Profile redesigns; light/dark and Dynamic Type polish. Prototype reference: `~/Downloads/Salary Meter Prototype.html` (decisions above override it).
- **Visual fixes (done):** glass state chip, seconds on Started, Records spacing/Total time/medals, toast placement, keyboard handling.
- **Live Activity round (done):** currency symbol everywhere, `Shared/` folder (one attributes file), Live Activity redesign per HIG, session goal (Settings + Meter card + Lock Screen bar), template widget removed, widget min iOS → 26.0.
- **Settings round (done):** Profile → Settings (gear), Settings-app style `Form`, no Saved toast.
- **Polish round (done):** Records index-bar clearance, cards above the list with a top fade (All Records and Top 10) while rows still scroll under the tab bar, Top 10 note as footer; state-colored landscape label/button and amber Pause; Hidden Tools sheet (first-use toggle, sample data, reset) replaces the ladybug menu and reset alert.

## Current round: iPhone Duo (IN PROGRESS — branch `iphone-duo`)

Design references (Eric's Figma exports, reference only — find alignment yourself, never measure pixels): `~/Downloads/Meter-outer-Portrait.png`, `Meter-outer-Portrait-fallback.png`, `Meter-outer-lanscape and standby.png`, `Meter-Inner-portrait.png`, `Meter-Inner-portrait-folded.png`, `Meter-inner-landscape.png`, `Meter-inner-landscape-folded.png`, `settings and hidden tools-portrait-outer.png`, `settings-inner-landscape.png`, `settings-inner-portrait-folded.png`, `Figma Tall Capsule.png`. Apple guidance: see memory `iphone-duo-guidelines` (HIG + dev page, read via JSON endpoint).

### Decisions (agreed with Eric, 2026-10-31; revised after simulator review)
**Two modes, switched by an "Alternative Look" toggle in Settings (`@AppStorage("display.alternativeLook")`, default OFF).**

| Pose | Alternative Look **OFF** (default) | Alternative Look **ON** (original Duo design) |
|---|---|---|
| Outer portrait | Meter page, buttons in the side bar, menu Meter / Records / Settings (Settings = page) | Same |
| Outer landscape | Black minimal meter (unchanged) | Same |
| Inner portrait | Bigger normal-iPhone Meter, bottom tab bar (3 items), wide bottom button; Settings = page | Same, but Settings = sheet |
| Inner portrait, folded | Chip + title stay; timer/amount/rate move up, info + button move down to clear the fold | Same (Settings = sheet) |
| Inner landscape | Meter page alone, buttons in the side bar, 3-item menu, Settings = page | **Home** = Meter ⅔ + Records ⅓, menu **Home / Settings**, buttons in side bar, Settings = sheet |
| Inner landscape, folded | Meter page split around the fold (proposed: hero left half, info + buttons right half) | Meter half (buttons under it) \| Records half |

- **Meter centering (side-bar layouts):** don't pin hero to top and info to bottom — vertically center the whole column with a moderate gap, so the middle isn't hollow.
- **Settings redesign (Apple Settings style), all Duo poses:** root list with colored icon rows → detail pages: **Currency** (symbol), **Income** (Income Type + fields + Your Rate Calculated), **Deductions**, **Session Goal**, plus the **Alternative Look** toggle row. Rows show the current value on the right. Inner display (flat/folded): `NavigationSplitView` sidebar list + detail side by side; outer: list → push with Back. (Open questions below on regular iPhones.)
- **Settings sheet** behavior (Phase 2, already built) applies only when Alternative Look is ON: sheet on regular width, page on outer portrait, fold/unfold swaps between them.
- **Hidden Tools**: 10 quick taps on the big amount, every layout except the black landscape view; closes only via X. (Done.)
- **Wide screens**: no "Go get an iPhone"; black view only for `verticalSizeClass == .compact`. (Done.)
- **Pose changes (Alternative Look ON)**: Records → Home when the menu becomes Home / Settings.
- Running/Paused use the same layouts with existing state colors and buttons. Paused side-bar actions are icon-only (▶ Resume, archivebox Archive & Reset); fallback = buttons in a bottom row if Eric dislikes them.
- No physical iPhone Duo: test in the iPhone Duo simulator. **Xcode Previews don't render Duo side bars** — side-bar layouts must be checked in the simulator.
- **Answered 2026-10-31:** (1) regular iPhones also get the Apple-style Settings; (2) Alternative Look toggle shown everywhere with footer "Applies to iPhone Duo only"; (3) default-mode inner landscape folded = hero on the left half, info on the right half, **buttons in the right-hand vertical side bar**; (4) icons: Currency `dollarsign` green, Income `briefcase.fill` blue, Deductions `percent` orange, Session Goal `flag.checkered` red, Alternative Look `rectangle.split.2x1` gray (can change later).
- **Records, default look, inner landscape folded:** All Records list on the left half, Top 10 on the right half (hinge clear; no segmented control needed there).

### API notes (verified against the iOS 27.1 SDK)
- `ArrangementView { } secondary: { }` + `.arrangementViewStyle(.split.axes(...))` — **iOS 27.1**.
- `GeometryProxy.reservedRegions(kind: .division)` (fold) — **iOS 27.1**; also occlusions (camera).
- `@Environment(\.toolbarVerticalEdge)` — **iOS 27.1** (non-nil when bars are on the side).
- `ToolbarItemVisibilityPriority` — **iOS 27.0**.
- App and widget minimum raised to **iOS 27.1** (Eric's call), so Duo APIs are used directly with no `#available` checks.
- Size classes: outer = compact width; inner = regular width. Use scene/container geometry, never `userInterfaceIdiom` or screen size.

### Phases (one per turn; build + check + commit on `iphone-duo`)
- [x] **1. Foundation** — min iOS 27.1; black view only for vertical-compact (also tab-bar hiding); "Go get an iPhone" removed; Hidden Tools = 10 taps on the amount, X to close. Meter adds top clearance when the top safe area is ~0 (Duo outer).
- [x] **2. Settings as a sheet (regular width)** — `RootTabView` `AppTab` selection interception, `SettingsView(isSheet:)` with X + detents, fold/unfold swaps sheet ↔ page. **To be gated behind Alternative Look ON in phase 5.**
- [x] **3. Side-bar actions** — `VerticalBarProbe` (`toolbarVerticalEdge`) → `barsOnSide`; actions become `.primaryAction` toolbar items (Start blue, Pause amber, Resume green `.glassProminent`; Archive & Reset glass), in-content buttons hidden, first-use hint under the info. Verified in simulator (outer portrait + inner landscape).
- [x] **4. Meter centering** (done: when `barsOnSide`, Spacers above and below the column center it; hero↔info gap `sideBarHeroGap` = 56pt) — side-bar layouts: center the column vertically with a moderate hero↔info gap (replace the top/bottom pinning Spacer).
- [x] **5. Settings redesign + Alternative Look toggle** (done: `ProfileKeys.alternativeLook` = `display.alternativeLook`; `RootTabView.settingsIsSheet` = alternativeLook && regular width; `syncSettingsPresentation()` runs on size-class and toggle changes. Sidebar rows use the system background on regular width so the selection highlight shows.) — Apple-style root list + detail pages (`NavigationSplitView`), value on each row, toggle row; gate the Phase 2 sheet behavior on the toggle.
- [~] **6. Inner portrait (flat + folded)** (built, awaiting simulator check of the fold: `isWidePortrait` = regular width && !barsOnSide → column capped at 640pt, hero/title text ×1.35, button row capped at 440pt, column centered with the button at the bottom. Fold: `horizontalFold(in:)` = first active `.division` reserved region wider than tall → `foldedPortraitLayout` puts chip/title + hero above the fold and `infoCards` + controls below, `foldClearance` 20pt each side. Previews can't fold.) — both modes: scaled layout, bottom tab bar; when folded, read the horizontal `reservedRegions(kind: .division)` and push hero up / info + button down.
- [ ] **7. Default-mode inner landscape folded** — Meter: hero left half | info right half, buttons stay in the right side bar. Records: All Records left | Top 10 right.
- [ ] **8. Alternative Look: inner landscape Home** — Meter ⅔ + Records ⅓, Home / Settings menu, Records → Home mapping.
- [ ] **9. Alternative Look: inner landscape folded** — `ArrangementView` split halves (Meter + buttons below | Records).
- [ ] **10. Polish** — light/dark, Dynamic Type, Running/Paused in every pose; simulator testing guide; update rules and move this round to Progress.

## Backlog (next rounds)

- Tap a record for its gross / deductions / net breakdown (data already stored for 2.3+ records).
- iCloud sync (storage is local SwiftData + AppStorage). Needs model defaults, no unique `id`, and a plan for settings and running sessions across devices — its own round.
- Verify first-use hint fits on smallest iPhone (iPhone SE width).
- Release prep for 2.3: version/build bump, full device pass, archive for TestFlight.

## Working with Eric

- Plan first, get approval, then build in phases — one phase per turn, build + render-check, commit per phase when asked.
- Work on a branch, merge to `main` and push only when Eric approves (Carl also pushes to this repo — fetch first).
- Flag conflicts with existing code instead of silently overwriting.
- Token budget matters: avoid long exploratory loops and repeated failing preview renders.
- Commit only the files you changed (leave `xcuserdata` alone).
