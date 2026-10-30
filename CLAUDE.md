# SalaryTimer ("Touch Fish")

iOS app that meters how much you earn per second. SwiftUI, SwiftData, ActivityKit. App target iOS 26.0 (Liquid Glass used directly, no fallbacks); widget extension target `TouchFish` (Live Activity).

## Architecture

| File | Role |
|---|---|
| `SalaryTimer/SalaryTimerStore.swift` | **Meter engine.** `MeterState` (idle/running/paused), segment math, persistence, Live Activity lifecycle. `RateCalculator` (all rate math). `ProfileKeys` (AppStorage keys). |
| `SalaryTimer/SalaryTimerApp.swift` | App entry, `RootTabView` (Meter / Records / Profile), `AmbientBackground` (3-state meter backdrop), `ScreenBackground` + `GroupedCard` (Records/Profile styling), `Color(hex:)`. |
| `SalaryTimer/ContentView.swift` | Meter tab: portrait layout, `LandscapeMeter`, `StateChip`, `StatTile`, toast, hidden reset, `contentCard` modifier. |
| `SalaryTimer/ProfileView.swift` | Income inputs, live rate preview card, Deductions, lock/paused banners. |
| `SalaryTimer/SessionLogView.swift` | Records: All Records (grouping, index bar, collapse, summary) + Top 10. `SessionFormatters` (shared formatting). |
| `SalaryTimer/DataSet.swift` | `SalarySession` SwiftData model. |
| `SalaryTimer/DebugSampleData.swift` | `#if DEBUG` only: ladybug menu in Records toolbar to add/remove random sample records (ids tracked in `debug.sampleRecordIDs`, so removal never touches real sessions). Use it to test Records on device. |
| `SalaryTimerAttributes.swift` (×2) | Live Activity data. **Two copies, one per target — keep them identical** (they differ only in indentation). |
| `TouchFish/SalaryTimerLiveActivity.swift` | Lock Screen / Dynamic Island UI. |

New files are picked up automatically (file-system synchronized groups). Swift 5 language mode, no default MainActor isolation.

## Core rules (decided with Eric — don't change without asking)

- **State machine:** Idle → Start. Running → Pause only. Paused → Resume + "Archive & Reset" (saves record, back to Idle). No archiving while running.
- **Segments:** each Start/Resume captures the Profile rate; each Pause locks in time/net/gross. Rate edits while paused apply only from the next Resume. Never compute `elapsed × current rate` for a whole session.
- **Timekeeping is timestamp-based** (no `Timer`); views tick via `TimelineView(.periodic(by: 1))`. Session state is persisted to UserDefaults (`meter.*` keys) on every transition and restored on launch, so it survives app kill.
- **Profile:** inputs locked while running, editable while paused. Deductions is one optional % (blank = 0% = "Gross"; entered = "Take-home"), clamped 0–100. Hourly and Monthly values are stored separately. Existing `profile.*` keys must stay (user data).
- **Records model:** `unitPrice` = session average net/sec; `startDate` and `grossEarned` are optional (nil for pre-2.3 records). Changing deductions never rewrites saved records.
- **Top 10:** `medal.fill` in gold/silver/bronze for 1–3, plain numbers after; no "Personal best" chip. Summary card is "Total time" in the same format as rows (`3min 6s`, `1h 42min`).
- **Records grouping:** Today / Yesterday / per day for 30 days, then per month. Section index labels: day number, or short month (`Sep`, `Sep ’25` outside current year). Collapsing hides rows only — header and index entry stay.
- **Visual language:** SF Pro family only; amount and title use SF Pro Rounded. Glass is for controls and status only (buttons, toasts, landscape button, tab bar, the Meter state chip as tinted glass); content cards are flat translucent fills. Profile rate card uses a green accent. Confirmations ("Saved to Records", Profile "Saved") use the shared `ToastView`. Idle blue, Running green, Paused dim green + amber chip. App follows system light/dark (landscape meter is always black). Money is shown as plain `$` (not locale `US$`).
- **Meter controls** sit at a fixed height in every state; first-use hint lives in a fixed 34pt slot above them (`@AppStorage("meter.hasArchived")`, shown in Paused until first archive).
- **Hidden reset:** 10 quick taps on an invisible 64×64pt area, top-right of Meter. Saves any metered time, resets meter, clears Profile.
- **Landscape:** chosen by width > height (`< 1000pt`; ≥1000pt shows "Go get an iPhone"). Tab bar hidden by shape, not size class (covers iPhone Duo inner display, keeps iPad's). iPhone Duo inner landscape is ~951pt wide, so it does not hit the iPad message.
- Portrait Meter caps Dynamic Type at XXX Large (beyond that, controls slide under the tab bar).

## Known gotchas

- **Xcode Previews crash** (iOS 27.1 / iPhone Duo sim) on any `List` with rows: "Could not cast UICollectionViewCell to SwiftUI.AnyListCollectionViewCell" from `PreviewsInjection`. Real app is fine. Records `#Preview` is intentionally empty — verify populated Records on simulator/device, not the canvas. Don't burn time bisecting it.
- Preview thunks are stricter than the real build: button action closures passed through helpers need `@MainActor () -> Void`.
- The default preview device is iPhone Duo; use the `Display: Inner/Outer` and `Orientation` variants to check foldable/landscape.

## Backlog (next rounds)

- Live Activity: deeper fixes (it's minimal — frozen "PAUSED" via `pausedAt`, refreshed every 15s while running, reconciled on launch).
- iCloud sync (storage is local SwiftData + AppStorage for now).
- Tap a record for its gross / deductions / net breakdown (data already stored for 2.3+ records).
- Verify first-use hint fits on smallest iPhone (iPhone SE width).
- Design prototype for the 2.3 redesign: `~/Downloads/Salary Meter Prototype.html` (visual reference only; decisions above override it).

## Working with Eric

- Plan first, get approval, then build in phases — one phase per turn, build + render-check, commit per phase when asked.
- Flag conflicts with existing code instead of silently overwriting.
- Token budget matters: avoid long exploratory loops and repeated failing preview renders.
- Commit only the files you changed (leave `xcuserdata` alone).
