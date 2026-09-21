# Bieżnia

Otwarta apka BLE do sterowania bieżnią z macOS. Bez apki producenta, bez konta, bez chmury.
Swift + SwiftUI, zero zależności, sam `CoreBluetooth`.

![Bieżnia](https://i.imgur.com/siYGcRq.png)

## 1. Protokół

Dwie usługi wystawione równolegle:

| Usługa | UUID | Opis |
|---|---|---|
| FTMS (Fitness Machine Service) | `0x1826` | standard Bluetooth SIG, przenośny między producentami |
| Fitshow | `0xFFF0` | kanał producenta, nieudokumentowany, format zdjęty z ramek |

Skan leci po `0x1826`. Po połączeniu `Capabilities` (`TreadmillClient.swift`) ustala, co urządzenie faktycznie wystawia.
Sam Fitshow: dane lecą, sterowania brak.

| UUID | Charakterystyka | Tryb | Zawartość |
|---|---|---|---|
| `0x2ACD` | Treadmill Data | notify | prędkość, dystans, czas, kalorie, tętno, moc |
| `0x2AD9` | Fitness Machine Control Point | write, notify | komendy i kody odpowiedzi |
| `0x2ADA` | Fitness Machine Status | notify | zdarzenia maszyny |
| `0x2AD3` | Training Status | read, notify | faza treningu |
| `0x2AD4` | Supported Speed Range | read | min, max, krok |
| `0x2ACC` | Fitness Machine Feature | read | mapa bitowa możliwości |

## 2. Zakres implementacji

### Odczyt `0x2ACD`

16-bitowe flagi, pola opcjonalne w stałej kolejności, little-endian (`odczytajDaneBiezni`, `ByteReader`).

| Bit | Pole | Typ | Skala |
|---|---|---|---|
| 0 | prędkość chwilowa (bit odwrócony: 0 = pole obecne) | uint16 | ÷100 km/h |
| 1 | prędkość średnia | uint16 | ÷100 |
| 2 | dystans | uint24 | m |
| 3 | nachylenie, kąt rampy | int16 ×2 | ÷10 |
| 4 | wzniesienie w górę, w dół | uint16 ×2 | ÷10 |
| 5 | tempo chwilowe | uint8 | ÷10 |
| 6 | tempo średnie | uint8 | ÷10 |
| 7 | kcal, kcal/h, kcal/min | uint16, uint16, uint8 | `0xFFFF` i `0xFF` = brak |
| 8 | tętno | uint8 | bpm, 0 = brak pasa |
| 9 | MET | uint8 | ÷10 |
| 10 | czas treningu | uint16 | s |
| 11 | czas pozostały | uint16 | s |
| 12 | siła na pasie, moc | int16 ×2 | N, W |

Nachylenie ze znakiem, uzupełnienie do dwóch.

### Sterowanie `0x2AD9`

Bez `Request Control` maszyna odrzuca komendy kodem `04`.

| Komenda | Bajty |
|---|---|
| Request Control | `00` |
| Start / Resume | `07` |
| Stop | `08 01` |
| Pause | `08 02` |
| Set Target Speed | `02 LL HH` (km/h ×100, LE) |

Odpowiedź: `80 <op> <kod>`. Kody: `01` ok, `02` nieobsługiwane, `03` zły parametr, `04` brak kontroli, `05` poza zakresem.

### Możliwości `0x2ACC`

UI renderuje kafelki i sterowanie na podstawie mapy bitowej, nie na sztywno (`Features.swift`).

Testowane urządzenie zwraca `c4 56 00 00 0f 00 00 00`:

* nadaje `0x000056C4`: dystans, kroki, opór, kalorie, tętno, czas, moc
* przyjmuje `0x0000000F`: prędkość, nachylenie, opór, moc

### Fitshow `0xFFF1`

STX/ETX, checksum XOR (`FitshowFrame.swift`):

```
02 51 03 3c 00 13 00 0d 00 09 00 00 00 00 00 79 03
│  │  │  └─┬─┘ └─┬─┘ └─┬─┘ └─┬─┘ └───┬────┘ │  └─ ETX
│  │  │    │     │     │     │       │      └─ XOR bajtów środka
│  │  │    │     │     │     │       └─ 5 zer: tętno i nachylenie, nieobsadzone
│  │  │    │     │     │     └─ kcal ×0,1
│  │  │    │     │     └─ dystans [m]
│  │  │    │     └─ czas [s]
│  │  │    └─ prędkość ×0,1
│  │  └─ status
│  └─ typ ramki, stałe 0x51
└─ STX
```

Status `0x02` skraca ramkę do odliczania: `02 51 02 05 56 03`.

Przy obu kanałach FTMS jest źródłem prawdy, z Fitshow brane są tylko kalorie ułamkowe i odliczanie,
czyli czego FTMS w tym modelu nie podaje.

## 3. Aplikacja

* autoskan po `0x1826`, reconnect co 2 s
* kafelki filtrowane przez `Features`, pokazywane tylko realne metryki
* sterowanie w granicach z `0x2AD4`
* sesja cięta na segmenty, bo bieżnia zeruje liczniki po każdym stopie; pauza nie kasuje wyniku
* eksport do `~/treningi/`: `.tcx` (Garmin TCD v2, wchodzi do Stravy) + `.json` na historię

```
Sources/Bieznia/
├── BLE/
│   ├── UUIDs.swift           identyfikatory usług i charakterystyk
│   ├── ByteReader.swift      odczyt little-endian
│   ├── Commands.swift        komendy i kody odpowiedzi
│   ├── Features.swift        dekoder 0x2ACC
│   ├── TreadmillData.swift   parser 0x2ACD
│   ├── FitshowFrame.swift    parser 0xFFF1
│   ├── TrainingStatus.swift  fazy treningu 0x2AD3
│   └── TreadmillClient.swift połączenie, stan, sesja
├── Export.swift              TCX, JSON, historia
└── UI/                       SwiftUI
```

## Build

macOS 13+, [Swift 5.10+](https://www.swift.org/install/macos/) albo [Xcode](https://apps.apple.com/app/xcode/id497799835).

```bash
./build-app.sh
open ~/Applications/Bieznia.app
```

Skrypt składa bundla z `Info.plist` i podpisem ad-hoc. Bez `NSBluetoothAlwaysUsageDescription` system utnie dostęp do BLE,
więc gołe `swift run` zadziała tylko jako proces bez uprawnień.

## Uwagi

Parser FTMS zgodny ze specyfikacją SIG, powinien wejść na inny sprzęt. Fitshow jest związany z konkretnym producentem.
Testowane na jednym modelu.

## Licencja

[MIT](LICENSE). Ikona pochodzi z clipartmax, licencja osobna od kodu.
