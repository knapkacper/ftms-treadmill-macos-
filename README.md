# ftms-treadmill-macos

Open source BLE app to control your treadmill from macOS. No vendor app, no account, no cloud.
Swift + SwiftUI, no dependencies, plain `CoreBluetooth`.

![FTMS Treadmill](https://i.imgur.com/siYGcRq.png)

## Install

```bash
git clone https://github.com/knapkacper/ftms-treadmill-macos-.git
cd ftms-treadmill-macos-
./build-app.sh
open ~/Applications/FTMSTreadmill.app
```

Update:

```bash
cd ftms-treadmill-macos-
git pull
./build-app.sh
```

macOS 13+, [Swift 5.10+](https://www.swift.org/install/macos/) or [Xcode](https://apps.apple.com/app/xcode/id497799835).
`build-app.sh` produces an ad-hoc signed bundle. `NSBluetoothAlwaysUsageDescription` lives in its `Info.plist`,
so a bare `swift run` gets no BLE access.

## 1. Protocol

Two services advertised in parallel:

| Service | UUID | Notes |
|---|---|---|
| FTMS (Fitness Machine Service) | `0x1826` | Bluetooth SIG standard, portable across vendors |
| Fitshow | `0xFFF0` | vendor channel, undocumented, format lifted off the wire |

Scan targets `0x1826`. After connect, `Capabilities` (`TreadmillClient.swift`) resolves what the device actually exposes.
Fitshow only: data flows, no control.

| UUID | Characteristic | Mode | Payload |
|---|---|---|---|
| `0x2ACD` | Treadmill Data | notify | speed, distance, time, calories, heart rate, power |
| `0x2AD9` | Fitness Machine Control Point | write, notify | commands and response codes |
| `0x2ADA` | Fitness Machine Status | notify | machine events |
| `0x2AD3` | Training Status | read, notify | workout phase |
| `0x2AD4` | Supported Speed Range | read | min, max, step |
| `0x2ACC` | Fitness Machine Feature | read | capability bitmap |

## 2. Implemented surface

### Read `0x2ACD`

16-bit flags, optional fields in fixed order, little endian (`odczytajDaneBiezni`, `ByteReader`).

| Bit | Field | Type | Scale |
|---|---|---|---|
| 0 | instantaneous speed (inverted: 0 = field present) | uint16 | ÷100 km/h |
| 1 | average speed | uint16 | ÷100 |
| 2 | total distance | uint24 | m |
| 3 | inclination, ramp angle | int16 ×2 | ÷10 |
| 4 | elevation gain, loss | uint16 ×2 | ÷10 |
| 5 | instantaneous pace | uint8 | ÷10 |
| 6 | average pace | uint8 | ÷10 |
| 7 | kcal, kcal/h, kcal/min | uint16, uint16, uint8 | `0xFFFF` and `0xFF` mean absent |
| 8 | heart rate | uint8 | bpm, 0 = no strap |
| 9 | MET | uint8 | ÷10 |
| 10 | elapsed time | uint16 | s |
| 11 | remaining time | uint16 | s |
| 12 | belt force, power | int16 ×2 | N, W |

Inclination is signed, two's complement.

### Control `0x2AD9`

Without `Request Control` the machine rejects everything with code `04`.

| Command | Bytes |
|---|---|
| Request Control | `00` |
| Start / Resume | `07` |
| Stop | `08 01` |
| Pause | `08 02` |
| Set Target Speed | `02 LL HH` (km/h ×100, LE) |

Response: `80 <op> <code>`. Codes: `01` ok, `02` not supported, `03` invalid parameter, `04` control not permitted, `05` out of range.

### Capabilities `0x2ACC`

Tiles and controls render off the bitmap, nothing is hardcoded (`Features.swift`).

Test unit reports `c4 56 00 00 0f 00 00 00`:

* transmits `0x000056C4`: distance, step count, resistance, calories, heart rate, elapsed time, power
* accepts `0x0000000F`: speed, inclination, resistance, power

### Fitshow `0xFFF1`

STX/ETX framing, XOR checksum (`FitshowFrame.swift`):

```
02 51 03 3c 00 13 00 0d 00 09 00 00 00 00 00 79 03
│  │  │  └─┬─┘ └─┬─┘ └─┬─┘ └─┬─┘ └───┬────┘ │  └─ ETX
│  │  │    │     │     │     │       │      └─ XOR over payload
│  │  │    │     │     │     │       └─ 5 zero bytes: heart rate and incline, unpopulated
│  │  │    │     │     │     └─ kcal ×0.1
│  │  │    │     │     └─ distance [m]
│  │  │    │     └─ time [s]
│  │  │    └─ speed ×0.1
│  │  └─ status
│  └─ frame type, always 0x51
└─ STX
```

Status `0x02` shortens the frame to a countdown digit: `02 51 02 05 56 03`.

With both channels up FTMS is the source of truth; Fitshow contributes only fractional calories and the countdown,
which this model omits from FTMS.

## 3. App

* auto scan on `0x1826`, reconnect every 2 s
* tiles filtered through `Features`, only metrics the hardware actually sends
* speed control clamped to `0x2AD4`
* session split into segments, since the treadmill zeroes its counters on every stop; pausing does not wipe the total
* export to `~/treningi/`: `.tcx` (Garmin TCD v2, imports into Strava) plus `.json` for in-app history

```
Sources/FTMSTreadmill/
├── BLE/
│   ├── UUIDs.swift           service and characteristic ids
│   ├── ByteReader.swift      little endian reads
│   ├── Commands.swift        commands and response codes
│   ├── Features.swift        0x2ACC decoder
│   ├── TreadmillData.swift   0x2ACD parser
│   ├── FitshowFrame.swift    0xFFF1 parser
│   ├── TrainingStatus.swift  0x2AD3 workout phases
│   └── TreadmillClient.swift connection, state, session
├── Export.swift              TCX, JSON, history
└── UI/                       SwiftUI
```

UI strings are English; source comments and identifiers are Polish.

## Notes

FTMS parser follows the SIG spec and should carry over to other hardware. Fitshow is vendor bound.
Tested against a single treadmill.

## License

[MIT](LICENSE). Icon sourced from clipartmax under its own terms, separate from the code.
