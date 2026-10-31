# SalaryTimer ("Touch Fish")

iOS app that meters how much you earn per second. SwiftUI, SwiftData, ActivityKit. Both the app and the widget extension `TouchFish` (Live Activity) target iOS 26.0 (Liquid Glass used directly, no fallbacks). Tabs: **Meter / Records / Settings**.

## Architecture

| File | Role |
|---|---|
| `SalaryTimer/SalaryTimerStore.swift` | **Meter engine.** `MeterState` (idle/running/paused), segment math, persistence, Live Activity lifecycle (start/update/end, 15s refresh while running, reconcile on launch). `RateCalculator` (all rate math). `ProfileKeys` (AppStorage keys, incl. `currencySymbol`, `sessionGoal`). `SessionGoal` (parses the optional goal). |
| `SalaryTimer/SalaryTimerApp.swift` | App entry, `RootTabView`, `AmbientBackground` (3-state meter backdrop), `ScreenBackground` + `GroupedCard` + `RowBackground` (Records/Settings styling), `ToastView` (shared glass toast), `Color(hex:)`. |
| `SalaryTimer/ContentView.swift` | Meter tab: portrait layout, `LandscapeMeter`, `StateChip` (tinted glass), `StatTile`, `GoalCard`, toast, hidden reset, `contentCard` modifier. |
| `SalaryTimer/SettingsView.swift` | Settings tab (gear icon; was "Profile"). Native grouped `Form` styled like the Settings app. |
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
- **Hidden Tools:** 10 quick taps on an invisible 64×64pt area, top-right of Meter, open a sheet. Debug builds only: Show First-Use Hint / Mark as Returning User (`meter.hasArchived`), Add / Remove Sample Records. Always: Reset App (confirm alert; saves any metered time, resets meter, clears Settings values, keeps Records). The sheet only closes via Done (`interactiveDismissDisabled`, so extra fast taps don't dismiss it); actions show a green ✓ confirmation line instead of closing.
- **Landscape:** chosen by width > height (`< 1000pt`; ≥1000pt shows "Go get an iPhone"). Tab bar hidden by shape, not size class (covers iPhone Duo inner display, keeps iPad's). iPhone Duo inner landscape is ~951pt wide, so it does not hit the iPad message.
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

### Decisions (agreed with Eric, 2026-10-31)
| Pose | Layout | Menu | Action buttons |
|---|---|---|---|
| Outer portrait | Hero block (chip, title, timer, amount, rate) top; info block (detail, tiles, goal) bottom, filling the screen | System side bar: Meter / Records / Settings | In the side bar above the menu (Apple "Buttons – 48pt", Symbol, vertical axis; try tall 164pt capsule, else native size). Paused = two icon-only buttons (▶ Resume, archivebox Archive & Reset). If side buttons don't work for Eric → **fallback**: buttons in a row at the bottom of content, and Idle/Running use the same bottom placement |
| Outer landscape | Existing black minimal meter (unchanged; tap shows/hides button) | Hidden | Bottom-right, as now |
| Inner portrait | Bigger normal-iPhone layout | Bottom tab bar, 3 items | Wide button at bottom |
| Inner portrait, folded | Chip + title stay; timer/amount/rate move up, info + button move down to clear the fold | Bottom tab bar, 3 items | Bottom |
| Inner landscape | **Home** = Meter left ⅔ + Records right ⅓ (add padding under the goal card) | Side bar: **Home / Settings** (2 items) | Side bar, above the menu |
| Inner landscape, folded | Meter left half, Records right half (fold clear) | Home / Settings (system places it) | Under the Meter, not on the side |
- **Settings is always a sheet** (every device and pose): tapping the Settings menu item presents a sheet (X button, grabber, medium→large detents, swipe down or tap outside to close) instead of switching tabs; the previous tab stays selected.
- **Hidden Tools**: trigger moves to **10 quick taps on the big amount** on every device and layout, **except the black landscape view** (its single tap still shows/hides the button). Remove the invisible top-right corner area. Sheet closes **only via an X** button (keep `interactiveDismissDisabled`).
- **Wide screens**: remove "Go get an iPhone". The black landscape view is only for `verticalSizeClass == .compact` (phones in landscape, Duo outer landscape). iPad gets the inner-display layouts.
- **Pose changes**: when switching from 3 items to Home/Settings, Records → Home (Home already shows Records). Settings sheet stays open across changes.
- Running/Paused use the same layouts with existing state colors and buttons. Outer landscape image's "StandBy" label is just the outer landscape meter (StandBy itself shows the Live Activity).
- No physical iPhone Duo: test in the **iPhone Duo simulator** (poses via Device Hub) and Xcode Previews (`Display: Inner/Outer`, `Orientation`; previews can't fold).

### API notes (verified against the iOS 27.1 SDK)
- `ArrangementView { } secondary: { }` + `.arrangementViewStyle(.split.axes(...))` — **iOS 27.1**.
- `GeometryProxy.reservedRegions(kind: .division)` (fold) — **iOS 27.1**; also occlusions (camera).
- `@Environment(\.toolbarVerticalEdge)` — **iOS 27.1** (non-nil when bars are on the side).
- `ToolbarItemVisibilityPriority` — **iOS 27.0**.
- App minimum stays **iOS 26.0**: wrap all Duo-specific code in `if #available(iOS 27.1, *)`; iOS 26 devices keep the current layouts.
- Size classes: outer = compact width; inner = regular width. Use scene/container geometry, never `userInterfaceIdiom` or screen size.

### Phases (one per turn; build + preview check + commit on `iphone-duo`)
- [ ] **1. Foundation** — `LayoutMode` resolver (size classes + width vs height + fold from reserved regions): `.phoneLandscape` (black), `.compact` (phone/outer portrait), `.regularPortrait`, `.regularLandscape`, each with `isFolded`. Black view only for vertical-compact; delete "Go get an iPhone" and the 1000pt rule (also in `RootTabView` tab-bar hiding). Split `ContentView` portrait into reusable `MeterHero`, `MeterInfo`, `MeterActions` views. Hidden Tools trigger → 10 taps on the amount (not in black view); remove corner area; Hidden Tools gets an X button.
- [ ] **2. Settings as a sheet** — tab-selection interception (3-item and 2-item menus) presents `SettingsView` in a sheet with X, detents, tap-outside dismiss; keep the previous tab selected.
- [ ] **3. Outer portrait** — hero top / info bottom filling the screen; action buttons as toolbar items in the side bar (`toolbarVerticalEdge` non-nil), try the tall capsule; Paused = two icon buttons. Keep a `useBottomActions` switch for the fallback.
- [ ] **4. Inner portrait (flat + folded)** — scaled-up layout, bottom tab bar, wide bottom button; when folded, read the horizontal division and push hero up / info down around it.
- [ ] **5. Inner landscape Home** — Meter ⅔ + Records ⅓, menu becomes Home / Settings, side-bar actions, Records→Home mapping on pose change.
- [ ] **6. Inner landscape folded** — `ArrangementView` split halves (Meter + actions below | Records), fold clear.
- [ ] **7. Polish** — light/dark, Dynamic Type, Running/Paused passes in every pose; write the simulator testing guide here; update rules sections above and move this round to Progress.

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
