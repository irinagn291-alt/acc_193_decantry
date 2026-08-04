# Decantry — Technical Specification

Offline home cellar: drinking windows, tasting notes, bottle cost.

## 1. Store metadata

- **Name:** Decantry
- **Subtitle:** Know what to open next
- **Short description:** Cellar wall with drinking windows
- **Long description:** Decantry maps every bottle on a rack wall and shows when it is ready, holding, or past peak. Log tastings, track purchase cost, and surface bottles whose drinking window closes this week. All data stays on device. No account, no ads, no cloud. Not a gambling product.
- **Keywords:** wine,cellar,bottle,tasting,vintage,rack,aging,spirits,offline,collection
- **Primary category:** Lifestyle
- **Secondary category:** Food & Drink
- **Age rating:** 17+ (Alcohol, Tobacco, or Drug Use or References)
- **Bundle ID:** com.decantry.cellar

## 2. Product goal

A single-device cellar desk for one home collection. Covers racks and cells, bottles and producers, purchases, tasting notes, drinking-window forecasts, and local JSON backup. No internet, no widgets, no notifications.

## 3. Platform and architecture

- iOS 16.4+, Swift 6.0, SwiftUI. iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`).
- MVVM, `ObservableObject` + `VMHolder` per screen. No `@Observable`.
- Persistence: hand-rolled SQLite via `libsqlite3`, actor `CellarStore`. Row decode via `(Row) throws -> T` closures — no `Statement` type.
- Navigation: `NavigationStack` hub (rack wall). iPad: two-column rack / bottle.
- Fixed dark UI via `INFOPLIST_KEY_UIUserInterfaceStyle = Dark`.
- No SPM. No UserNotifications.

### 3.1 Database layer

```
CellarStore   — actor, one sqlite3 handle, WAL, foreign_keys ON
Row           — [String: SQLValue] with typed accessors
Migrator      — PRAGMA user_version, SchemaV1
*Repository   — maps rows; ViewModels talk only here
```

Money = INTEGER cents. Dates = INTEGER Unix. UUID = TEXT lowercase. No SQL interpolation.

## 4. Domain model

```swift
enum MaturityStage: String { case young, approaching, ready, holding, pastPeak }
enum BottleKind: String { case wine, spirit, fortified, other }
enum CellStatus: String { case empty, occupied, reserved }

struct Producer { let id: UUID; var name: String; var region: String; var country: String; var note: String }
struct Rack { let id: UUID; var name: String; var rows: Int; var columns: Int; var sortOrder: Int }
struct Cell { let id: UUID; var rackID: UUID; var row: Int; var column: Int; var status: CellStatus; var bottleID: UUID? }
struct Bottle {
    let id: UUID; var producerID: UUID?; var name: String; var kind: BottleKind
    var vintage: Int?; var grapeOrBase: String; var abvPercent: Double?
    var purchasedAt: Date?; var purchaseCents: Int; var currencyCode: String
    var peakStartYear: Int?; var peakEndYear: Int?; var cellarTempC: Double
    var note: String; var drunkAt: Date?; var isArchived: Bool
}
struct Tasting {
    let id: UUID; var bottleID: UUID; var tastedAt: Date
    var score: Int; var nose: String; var palate: String; var finish: String; var note: String
}
struct Purchase {
    let id: UUID; var bottleID: UUID; var purchasedAt: Date
    var storeName: String; var cents: Int; var quantity: Int
}
struct CellarProfile {
    let id: UUID; var displayName: String; var defaultTempC: Double; var currencyCode: String
}
```

## 5. Core logic

### 5.1 DrinkingWindowCalculator

Given bottle vintage, peakStart/End, cellarTempC, and `asOf: Date`:
- Base midpoint = mean of peak years (or vintage+8 if unset).
- Temp adjustment: each °C above 13 shortens window by ~6 months; below lengthens.
- Stage from years-to-peak and years-past-peak:
  - young: >3y before peak start
  - approaching: within 3y of peak start
  - ready: inside [peakStart, peakEnd]
  - holding: 0–2y after peak end
  - pastPeak: >2y after peak end
- `closingThisWeek(bottles)`: ready/holding bottles whose computed remaining days ≤ 7.

### 5.2 Cost insights

Average cost per tasting = purchaseCents / max(1, tastingCount). Surface bottles with high cost and zero tastings.

## 6. Screens

| Screen | Contents | Navigates to |
|--------|----------|--------------|
| SplashGate | Wordmark + bootstrap | Onboarding / RackWall |
| Onboarding (3) | Profile → first rack → sample bottle | RackWall |
| RackWall | Grid of cells colored by maturity | RackDetail, DrinkNext, Settings |
| RackDetail | Single rack grid | BottleDetail, PlaceBottle |
| BottleDetail | Meta, window dial, tastings | TastingEditor, EditBottle |
| PlaceBottle | Pick empty cell / create bottle | BottleDetail |
| DrinkNext | Closing-this-week list | BottleDetail |
| TastingList | All tastings filtered | TastingEditor |
| TastingEditor | Score + notes form | — |
| ProducerList / Detail | Producers | BottleDetail |
| LedgerView | Purchases + cost averages | BottleDetail |
| InsightsView | Window histogram, dead stock | BottleDetail |
| BackupView | Export/import JSON | — |
| SettingsView | Profile, temp, currency, about | BackupView |
| EmptyCellar | Illustration + CTA | PlaceBottle |

~16 screens.

## 7. Design

- Background `#1B1D22`, surface `#24262C`, oak `#8A6A3E`, wine `#6E1E2C`, brass `#C9A24A`, text `#F2EDE4`, secondary `#A39E94`.
- Corners 8/12. Accent < 5% of screen. No purple, neon, materials.
- Typography: title serif-feel via `.serif` design where available; numerals monospaced.
- `DecantTokens`, `DecantChrome`, `DecantEmpty`.

## 8. Storage

- SQLite: Application Support / `decantry.sqlite` (WAL).
- UserDefaults: `decantry.onboardingCompleted`, `decantry.seedVersion`.
- Documents / Backups for JSON export.

## 9. Delivery phases

1. Bootstrap + Theme + Root/Onboarding
2. CellarStore + repositories + seed
3. DrinkingWindowCalculator + tests
4. Rack wall + bottle flows
5. Tastings, ledger, insights, backup
6. Assets + metadata

## 10. Testing

- DrinkingWindowCalculator stages and temp adjustment
- Repository CRUD on in-memory store
- Backup round-trip
- Smoke: app launches, seed present

## 11. Privacy

- No tracking. PrivacyInfo: UserDefaults `CA92.1`, FileTimestamp `C617.1`.
- Documents usage description for backup import/export.
- No notification keys.

## 12. Visual assets

### App icon (1024×1024, no alpha)

| Variant | Description |
|---------|-------------|
| light | Dark slate bottle silhouette with brass neck ring |
| dark | Same, deeper oak wood grain behind |
| tinted | Monochrome bottle outline, light on transparent |

### Illustrations (magenta chroma → alpha, ~1024 long edge)

`onboarding-profile`, `onboarding-rack`, `onboarding-bottle`, `rack-banner`, `empty-cellar`, `empty-tastings`, `empty-ledger`, `drink-next-banner`, `maturity-dial`, `backup-empty`
