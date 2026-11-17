# SalaryTimer ("Touch Fish")

iOS app that meters how much you earn per second. SwiftUI, SwiftData, ActivityKit. Both the app and the widget extension `TouchFish` (Live Activity) target **iOS 27.1** (raised from 26.0 in the iPhone Duo round) (Liquid Glass used directly, no fallbacks). Tabs: **Meter / Records / Settings**.

## Architecture

| File | Role |
|---|---|
| `SalaryTimer/SalaryTimerStore.swift` | **Meter engine.** `MeterState` (idle/running/paused), segment math, persistence, Live Activity lifecycle (start/update/end, 15s refresh while running, reconcile on launch). `RateCalculator` (all rate math). `ProfileKeys` (AppStorage keys, incl. `currencySymbol`, `sessionGoal`). `SessionGoal` (parses the optional goal). |
| `SalaryTimer/SalaryTimerApp.swift` | App entry, `RootTabView` (tabs, Home / Settings switching, Settings sheet sync), `HomeView` (Alternative Look combined Home), `GeometryProxy` fold helpers, `AmbientBackground` (3-state meter backdrop), `ScreenBackground` + `GroupedCard` + `RowBackground` (Records/Settings styling), `ToastView` (shared glass toast), `Color(hex:)`. |
| `SalaryTimer/ContentView.swift` | Meter tab: portrait, wide-portrait, folded-portrait and folded-landscape layouts, `LandscapeMeter` (statement + super minimal looks), side-bar actions + `VerticalBarProbe`, `StateChip` (tinted glass), `StatTile`, `GoalCard`, toast, Hidden Tools (10 taps on the amount), `contentCard` modifier. |
| `SalaryTimer/AppFont.swift` | Role-based font tokens (see Visual language). |
| `SalaryTimer/WelcomeView.swift` | First-launch Welcome sheet, presented by `RootTabView`. |
| `SalaryTimer/SettingsRouter.swift` | `SettingsRouter` (environment object from `RootTabView`): `open(.income(focusing:))` presents Settings and the visible `SettingsView` pushes the pane and focuses the field. |
| `SalaryTimer/SettingsView.swift` | Settings tab (gear icon; was "Profile"). Apple Settings style: `NavigationSplitView` root list (icon rows Currency / Income / Deductions / Session Goal with current values, Alternative Look toggle) → detail `Form` pages via `paneForm`. Wide screens show list + page side by side (starts on Currency); phones push. `isSheet` adds an X. |
| `SalaryTimer/SessionLogView.swift` | Records: All Records (monthly statement: `MonthSelector`, `SessionGrouping.months` → `SessionMonthGroup` / `SessionDayGroup`, index bar, summary) + Top 10. `SessionFormatters` (durations, dates, money via `Money`). |
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
- **Controls** sit at a fixed height in every state; the fixed 34pt slot above them shows, in priority order: the **setup notice** (Idle and income missing: "Set your income to start the meter ›", taps deep-link to the first missing field), else the **first-use hint** (`@AppStorage("meter.hasArchived")`, Paused until first archive). Side-bar layouts show the same line inline under the cards.
- **Start gate:** Start/Resume (portrait and side bar) with missing income fields (`RateCalculator.missingFields`) shows "Set your income first" naming them, with **Set Hourly Rate** (or "Set Up Income" for several) / **Start Anyway** / **Cancel**. Set … opens Settings → Income with that field focused via `SettingsRouter` (tab page; sheet with Alternative Look on wide screens and on the Home). Start Anyway runs at $0 and still starts the Live Activity. **Landscape has no gate**: its only action is its button, everything else needs portrait.
- **Welcome sheet** (`WelcomeView`) on first launch while Idle (`onboarding.hasSeenWelcome`): one page, three feature rows, **Set Up Income** (closes, then opens Settings → Income on the first missing field via `SettingsRouter`) / **Not Now**. Set as seen on any dismissal.
- **Card groups** (`infoCards`, shared by every portrait/side-bar/fold layout): caption **NEXT SESSION** (Idle) / **THIS SESSION** → detail card (first line "Started HH:MM:SS" when Running/Paused, then the rate: "Gross $60.00/hr — no deductions" / "Take-home $48.00/hr after 20% deductions" / "No income set") → **Goal card** (only when a goal is set: "62% of $400" or "✓ Reached", bar tinted by state) → caption **FROM RECORDS** → Today so far / Last session tiles. No "At this rate" line.
- Under the hero amount the rate is a quiet secondary line (`≈ $0.0167/sec` / "No rate set"), no capsule.
- **Hidden Tools:** 10 quick taps on the big amount (any layout except the black landscape view) open a sheet; it closes only via its X. Debug builds only: Show First-Use Hint / Show Welcome on Next Launch / Mark as Returning User (`meter.hasArchived` + `onboarding.hasSeenWelcome`), Add / Remove Sample Records. Always: Reset App (confirm alert; saves any metered time, resets meter, clears income, deductions and goal, re-arms the Welcome sheet; keeps currency, display toggles and Records). `interactiveDismissDisabled`, so extra fast taps don't dismiss it; actions show a green ✓ confirmation line instead of closing.
- **Landscape** (`LandscapeMeter`, always black): only when `verticalSizeClass == .compact` (phones in landscape, Duo outer landscape); the tab bar hides there too. Regular-height sizes (Duo inner display, iPad) never get it. No "Go get an iPhone" anymore. Default **statement look** (adapted from the Lock Screen Live Activity): solid state chip top-left, rate top-right (`$60.00/hr ≈ $0.0167/sec` / "No rate set"), elapsed over the big amount (leading-aligned), goal bar bottom-left (fixed 36pt row even without a goal, so the hero never moves), Start/Pause/Resume button bottom-right. **Super Minimal Landscape** toggle (`display.superMinimalLandscape`) restores the old view: amount + time centred, state label top-left. Both: 24pt insets, the button is the only action (hides after 3.5s, tap anywhere to show), no Start gate, no Hidden Tools.
- Portrait Meter caps Dynamic Type at XXX Large (beyond that, controls slide under the tab bar).

### Settings
- Native `Form` sections, each with a short footer: **Currency** (symbol menu) → **Income** (Income Type menu + matching fields; footer "Changes only affect upcoming sessions.") → **Your Rate Calculated** (green-tinted rows, bold green total) → **Deductions** → **Session Goal**. Values right-aligned with gray units, no boxed fields, headers without "(optional)" (placeholder says Optional).
- **Root list** sections with headers (like Screen Time): **Income** (Currency, Income) · **Optional Settings** (Deductions, Session Goal) · **Alternative Look** (toggles **iPhone Duo Special Look** = `display.alternativeLook`, and **Super Minimal Landscape** = `display.superMinimalLandscape`, off by default; one shared footer). Toggles are never locked.
- Inputs locked while running: an amber-tinted card at the top of the list and every page (`lock.fill`, "Locked while running" + "Pause the meter to edit. Changes apply when you resume."). Paused: gray line "Paused — changes apply when you resume." No "Saved" toast — values auto-save. Focused field is scrolled to center so the keyboard's floating Done button doesn't cover it; 72pt bottom content margin clears the tab bar.
- Deductions is one optional % (blank **or 0** = Gross, "No deductions"; > 0 = "Take-home"), clamped 0–100. Hourly and Monthly values are stored separately. Existing `profile.*` keys must stay (user data).
- **Currency symbol:** `$ € £ ¥ ₹ ₩ ₽ ₺ ₱ ฿ R$ kr CHF`, no custom. Always before the number (letter symbols get a space: `kr 12.50`). Label only — no conversion; changing it relabels every amount including old records. All money goes through `Money.string`.
- **Session goal:** optional `profile.sessionGoal`. Blank = no goal: no card, no bar anywhere; the Settings row shows "None".

### Records
- **Model:** `unitPrice` = session average net/sec; `startDate` and `grossEarned` are optional (nil for pre-2.3 records). Changing deductions never rewrites saved records.
- **Statement view (All Records):** one month at a time. `MonthSelector` under the summary cards: ‹ (older) · **November ⌄** (primary; menu lists every month with records and its total) · › (newer; dimmed at the ends), with the blue line "$3,619.01 · 37 sessions" under the title. Day sections "Today" / "Yesterday" / "Mon, Nov 3" with the blue day total; header titles line up with the row amounts (no offset). Index bar = that month's day numbers. No collapse. Months without records can't be selected; deleting a month's last row falls back to the newest month. No records → `ContentUnavailableView` ("No records yet"), also on Top 10.
- **Rows:** amount, then `duration · $x/sec` (middle dot), time trailing on the amount's baseline. Top 10 medal/number sits on the amount line.
- **Summary** cards sit above the list (not in its scroll area), so rows never pass behind them; the list's top 24pt is a gradient mask (extended past the bottom so rows still scroll under the tab bar) (`topFade()`, also used on Top 10 under the segmented control) so rows fade out before reaching what's above. No extra trailing margin: the system already insets rows for the index bar (an added margin squared off the cards' right corners and put the index over the times). Cards stay **all time**: Total earned / Total time (same format as rows: `3min 6s`, `1h 42min`) / Sessions; the month total lives in the selector. **Top 10:** `medal.fill` gold/silver/bronze for 1–3, plain numbers after, no "Personal best" chip; "Top 10 by earnings, across all sessions." is the section footer under the rows.

### Live Activity
- Moving parts are only Apple's built-in timer views: the elapsed **timer** and a timer-driven `ProgressView` **goal bar** ($0 → goal over the whole session; hidden without a goal; green ✓ beside "Goal $X" once reached as of the last app update).
- **Lock Screen / expanded:** RUNNING/PAUSED chip + rate (`$50.00/hr ≈ $0.0139/sec`), timer as hero, goal bar. System background, 14pt margins.
- **Goal ring** (`GoalRing`): state-colored circular `ProgressView` filling $0 → goal (timer-driven like the bar), currency symbol inside. No goal = full ring in the state color. No timer inside (minimal is ~36pt; `1:02:03` won't fit).
- **Compact:** live timer left, goal ring right (replaced the `$50/hr` capsule). **Minimal** (shown when another app's Live Activity is also running): goal ring. Keyline follows state. Running green, paused amber.
- **Apple Watch Smart Stack / CarPlay:** `.supplementalActivityFamilies([.small])`; `LockScreenView` switches on `activityFamily` to `SmallMeterView` (big ring left; state, live timer, `$50/hr` right; no buttons). Without `.small` the Watch would combine the compact leading/trailing views. In Xcode previews use View Style "Content (Smart Stack)" + Dark Appearance (light renders white text on white).
- The amount itself can't tick on the Lock Screen (see gotchas); it only updates when the app pushes (15s loop while the app runs, plus on start/pause/resume). No push server — decided.

### Visual language
- SF Pro family only; amount and title use SF Pro Rounded. Glass is for controls and status only (buttons, toasts, landscape button, tab bar, the Meter state chip as tinted glass); content cards are flat translucent fills. Confirmations ("Saved to Records") use the shared `ToastView`, placed outside any `NavigationStack` so it sits just below the Dynamic Island.
- **Type:** roles come from `AppFont` (text styles, so they scale with Dynamic Type): `label` caption2 bold + 0.8 tracking (uppercase card labels and captions), `chip` caption bold, `value` title3 rounded bold (tile/row amounts), `summaryValue` headline rounded bold (Records summary). Meter hero sizes (amount 64, title 22, timer 17, rate 13) are `@ScaledMetric` × `heroScale`. Fixed sizes only in the capped landscape meter, `SettingsIcon` and the Welcome icon; don't add new `.system(size:)` elsewhere. Records summary cards: equal height (`GroupedCard(fillsHeight:)`), 12pt padding, label tracking 0.4 so three fit a phone width.
- Empty values read as words via `ValueLabels` (`Shared/`): No rate set / No income set / No deductions / No goal / No sessions yet / Not set / None. Never show a raw `$0.00/hr` or `0%`.
- Idle blue, Running green, Paused dim green + amber chip. App follows system light/dark (landscape meter is always black). Records and Settings use the navy `ScreenBackground` in dark mode.

## Known gotchas

- **Custom `FormatStyle`s in `Text(.currentDate, format:)` render as grey placeholder bars in Live Activities** (tested on device). Only Apple's built-in date/timer styles tick on their own. A "next dollar" progress bar was also tried and dropped: once full it can't restart without the app.
- The Live Activity request used to be skipped at a $0 rate (`segmentNetPerSecond > 0` guard), so Start Anyway users got none. Don't reintroduce a rate guard; the widget shows "No rate set" and its timer-driven bars only divide when `fillsLive` (rate > 0).
- **Alerts on Duo side-bar poses** (outer portrait, inner landscape, the Home) are centred by iOS over the content area beside the side bar, not the whole screen. System placement, no public API to move it; accepted (checked 2026-11-17).
- **Live timer `Text(timerInterval:)` always uses tabular digits** (removing `.monospacedDigit()` changes nothing), so a leading "1" (`14:48`, `1:02:03`) looks indented vs. left-aligned text above/below. Accepted as is (Apple's timers do the same); the app can't know when the timer passes 10:00 to nudge it.
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
- **iPhone Duo round (done):** min iOS 27.1, size-class black view, Hidden Tools on the amount, side-bar actions, centered side-bar Meter, wide portrait sizing, fold-aware portrait/landscape Meter and Records, Apple-style split Settings everywhere, Alternative Look toggle (Settings sheet + combined Home). See the iPhone Duo section.
- **Duo adjustments (done, merged):** Records rows keep rounded corners beside the index; Home swapped (Records ⅓ left, Meter right) with no menu and a side-bar Settings gear; Settings reopens on its root after leaving the tab.
- **Release prep (code done, merged; upload pending):** version 3.0 (1), Touch Fish naming, privacy manifest, export compliance key; toast above the state chip; Live Activity goal ring (compact + minimal) and Watch/CarPlay layout. See the Release 3.0 section.
- **Feedback round (in progress, branch `feedback-round`):** P1 Live Activity at $0, `ValueLabels`, 0% = no deductions, `RateCalculator.missingFields`. P2 Start gate, setup notice, Settings deep link. P3 Welcome sheet. P4 Meter card groups, Started first, quiet rate line. P5 Settings section headers, amber locked card, Super Minimal Landscape toggle. P6 statement landscape (default) + super minimal option. P7 Records monthly statement. P8 `AppFont` tokens, scaled heroes, matching summary cards.

## iPhone Duo (done 2026-10-31, branch `iphone-duo`)

Apple guidance: memory `iphone-duo-guidelines` (HIG + dev page; read via the JSON endpoint). Eric's Figma references live in `~/Downloads` (reference only; never measure pixels).

### Layout rules
| Pose | Alternative Look **OFF** (default) | Alternative Look **ON** |
|---|---|---|
| Outer portrait | Meter centered, buttons in the side bar, menu Meter / Records / Settings, Settings = page | Same |
| Outer landscape | Black minimal meter | Same |
| Inner portrait (flat) | "Bigger iPhone": column ≤ 640pt, hero/title ×1.35, button row ≤ 440pt, centered, bottom tab bar | Same, Settings = sheet |
| Inner portrait (half open) | Chip + title + hero above the fold, info cards + button below | Same |
| Inner landscape (flat) | Meter page centered, buttons in the side bar | **Home** (Records ⅓ + Meter ⅔), no menu, side bar = actions + Settings gear (sheet) |
| Inner landscape (half open) | Meter: hero left of the fold, info right, buttons in the side bar. Records: All Records left, Top 10 right | Home: Records left half, Meter right half, same side bar |

### How it works
- **Detection:** size classes (outer = compact width, inner = regular), `verticalSizeClass == .compact` for the black view, `VerticalBarProbe` reads `toolbarVerticalEdge` into `barsOnSide`, and `GeometryProxy.horizontalFold` / `.verticalFold` (SalaryTimerApp.swift) read active `.division` reserved regions. Never use `userInterfaceIdiom` or screen size.
- **Side-bar actions:** `.primaryAction` toolbar items with title + symbol (custom frames stop them being shown vertically, so no tall capsule). Paused = ▶ Resume + archivebox Archive & Reset, icon-only.
- **Settings:** always the Apple-style split list (`NavigationSplitView`) on every device. With Alternative Look ON and regular width it's a sheet (`RootTabView.settingsIsSheet`); `syncSettingsPresentation()` swaps page ↔ sheet on fold/unfold and toggle changes.
- **Home:** `RootTabView.usesHome` = alternativeLook && regular/regular && landscape. Then `RootTabView` shows `HomeView` **instead of** the `TabView` (hiding the tab bar didn't remove the side-bar menu). `HomeView` sizes `SessionLogView(isEmbedded: true)` | `ContentView(onOpenSettings:)` by ⅓ or by the fold, so each child sees no fold. The Meter adds a Settings gear (`.bottomBar` → bottom of the side bar) next to its actions. Embedded Records has **no `NavigationStack`** (its UIKit container reserved the side bar's width and squeezed the column), draws its own large title, and stacks its summary (Total earned + Total time, then a one-line Sessions card).
- **Settings resets to its root** whenever the user leaves the Settings tab (`settingsResetID` → `.id`). Fold/unfold page ⇄ sheet swaps may keep the current page.
- **Toast:** placed inside the Meter's geometry; when half open in landscape it centers over the left half.
- **Hidden Tools:** 10 taps on the big amount (not in the black view); closes only via X.
- Alternative Look in inner **portrait** keeps the Meter / Records / Settings bar (Settings = sheet).
- Min iOS **27.1** (app + widget), so Duo APIs are used directly.

### Testing in the simulator (no physical device)
1. Run destination → **iPhone Duo** simulator, ⌘R. Rotate with ⌘← / ⌘→.
2. Switch outer/inner display and fold poses with the Device Hub pose controls.
3. Previews can show Display Inner/Outer and orientation, but **not side bars or folds** — check those in the simulator.
4. For fold work, a temporary `#if DEBUG` readout of `geo.reservedRegions(kind: .division)` frames is the fastest way to confirm detection (used and removed in this round; values seen: portrait band y373 h40, landscape band x455 w40).
5. Check each pose in Idle / Running / Paused, light and dark, with Alternative Look on and off.

## Release 3.0 (in progress, code merged to `main`)

First ever App Store / TestFlight release. Eric bought the Apple Developer Program (Individual) on 2026-10-31 and is waiting for approval. Nothing has been uploaded yet.

### Done in code
| What | Where | Notes |
|---|---|---|
| Version **3.0**, build **1** | Build settings `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, app **and** widget (must match) | Bump the build number (2, 3, …) for every new upload of 3.0; App Store Connect rejects a repeated number. |
| Home Screen name **Touch Fish** | App `INFOPLIST_KEY_CFBundleDisplayName` | Was "Salary Timer". |
| Extension display name **Touch Fish Meter** | Widget `INFOPLIST_KEY_CFBundleDisplayName` | Only visible in system lists. |
| Privacy manifest | `SalaryTimer/PrivacyInfo.xcprivacy` | No tracking, no collected data; declares UserDefaults (AppStorage + `meter.*`) with reason `CA92.1`. The widget doesn't use UserDefaults, so it has none. Add entries if a new required-reason API is used (file timestamps, disk space, system boot time). |
| Export compliance | App `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` | No custom encryption, so TestFlight doesn't ask each upload. |

### Naming (decided)
- App Store **Name:** `Touch Fish`, **Subtitle:** `Meter Your Free Money` (both set in App Store Connect, 30-char limit each; "Touch Fish - Meter Your Free Money" is 34 so it can't be the name). Backup if the name is taken: `Touch Fish: Meter Free Money`.
- **Unchanged on purpose:** bundle IDs `tech.SalaryTimer` / `tech.SalaryTimer.TouchFish` (invisible, permanent once on the store), Xcode project/target/scheme names `SalaryTimer` / `TouchFish` (renaming risks signing, users never see them).

### Remaining steps (walk Eric through them; it's his first release)
1. **Approval** email ("Welcome to the Apple Developer Program"), same Apple ID as Xcode.
2. **Xcode → Settings → Accounts:** team shows "(Individual)", not "Personal Team". In Signing & Capabilities for **SalaryTimer** and **TouchFishExtension**: automatic signing, paid team. If `DEVELOPMENT_TEAM` (`KWFBN78X3K`) changes, commit the pbxproj change.
3. **App Store Connect → Apps → + New App:** iOS, name/subtitle above, English, bundle ID `tech.SalaryTimer` (if missing, run once on device from Xcode to register it), SKU e.g. `salarytimer-001`, Full access.
4. **Archive:** destination **Any iOS Device (arm64)** → Product → Archive → Organizer → Distribute App → App Store Connect → Upload.
5. **Processing** 5–30 min, then the build shows in the TestFlight tab.
6. **Internal testing:** create a group, add Eric, add the build, install via the TestFlight app (no review needed). TestFlight replaces the Xcode-installed copy; data normally survives but screenshot totals first.
7. **External testing (optional):** beta description, feedback email, one-time Beta App Review (~1 day). Testers need iOS 27.1+.
8. Before App Store submission (later): App Privacy questionnaire = "Data Not Collected", screenshots, description, privacy policy URL, support URL.

### Waiting on Eric
- Approval; screenshot of any signing error in step 2.
- Whether Carl gets TestFlight / App Store Connect access (Users and Access first).
- (Merged and pushed 2026-11-01.)
- Device pass on the TestFlight build: Live Activity (Lock Screen + Dynamic Island), kill mid-session and relaunch, light/dark, large Dynamic Type, first-use hint on the smallest iPhone.

## Backlog (next rounds)

- Tap a record for its gross / deductions / net breakdown (data already stored for 2.3+ records).
- iCloud sync (storage is local SwiftData + AppStorage). Needs model defaults, no unique `id`, and a plan for settings and running sessions across devices — its own round.
- Verify first-use hint fits on smallest iPhone (iPhone SE width).
- Release 3.0 to TestFlight: see the Release section (waiting on Developer Program approval).

## Working with Eric

- Plan first, get approval, then build in phases — one phase per turn, build + render-check, commit per phase when asked.
- Work on a branch, merge to `main` and push only when Eric approves (Carl also pushes to this repo — fetch first).
- Flag conflicts with existing code instead of silently overwriting.
- Token budget matters: avoid long exploratory loops and repeated failing preview renders.
- Commit only the files you changed (leave `xcuserdata` alone).
