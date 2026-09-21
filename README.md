# Bieżnia

Aplikacja na macOS, która łączy się z bieżnią po Bluetooth Low Energy, pokazuje dane treningu na żywo,
steruje prędkością i zapisuje trening do pliku TCX (import do Stravy, Garmin Connect itp.).

Napisana w Swift + SwiftUI, bez zewnętrznych zależności — tylko `CoreBluetooth` z systemu.

![Bieżnia — widok treningu](https://i.imgur.com/siYGcRq.png)

---

## 1. Na jakim protokole działa bieżnia

Bieżnia jest urządzeniem **Bluetooth Low Energy (BLE)**. Nie ma tu "parowania" jak przy słuchawkach —
urządzenie rozgłasza (*advertising*) swoje usługi, aplikacja je znajduje, łączy się i nasłuchuje powiadomień.

Bieżnia wystawia dwa kanały równolegle:

| Kanał | UUID usługi | Co to jest |
|---|---|---|
| **FTMS** (Fitness Machine Service) | `0x1826` | Oficjalny, standardowy profil Bluetooth SIG dla sprzętu fitness (bieżnie, rowerki, orbitreki). Działa tak samo u każdego producenta, który go wspiera. |
| **Fitshow** | `0xFFF0` | Prywatny kanał producenta (tzw. *vendor-specific*). Nieudokumentowany, format odczytany z ramek. Tania elektronika często wysyła tędy dane dokładniejsze niż przez FTMS. |

Aplikacja skanuje tylko po `0x1826`, a po połączeniu sprawdza, które kanały urządzenie faktycznie ma
(`Capabilities` w `TreadmillClient.swift`). Jeśli jest tylko Fitshow — aplikacja i tak pokazuje dane, ale bez sterowania.

### Charakterystyki FTMS używane przez aplikację

Charakterystyka to pojedynczy "kanał danych" wewnątrz usługi. Ma swój UUID i tryb pracy: odczyt, zapis albo powiadomienia.

| UUID | Nazwa | Tryb | Do czego służy |
|---|---|---|---|
| `0x2ACD` | Treadmill Data | notify | Dane na żywo: prędkość, dystans, czas, kalorie, tętno, moc |
| `0x2AD9` | Fitness Machine Control Point | write + notify | Wysyłanie komend (start, stop, prędkość) i odbieranie odpowiedzi |
| `0x2ADA` | Fitness Machine Status | notify | Zdarzenia od bieżni: start, pauza, zatrzymanie przez użytkownika |
| `0x2AD3` | Training Status | read + notify | Faza treningu: gotowa / odliczanie / bieg / zwalnianie |
| `0x2AD4` | Supported Speed Range | read | Min., maks. prędkość i krok zmiany (u nas 1,0–6,0 km/h, krok 0,1) |
| `0x2ACC` | Fitness Machine Feature | read | Mapa bitowa: co bieżnia umie nadawać i co da się jej ustawić |

---

## 2. Jakie funkcje protokołu wspiera aplikacja

### Odczyt danych (`0x2ACD`)

Ramka zaczyna się od 16-bitowych **flag**. Każdy bit mówi, czy dalej w ramce jest dane pole.
Pola występują zawsze w tej samej kolejności, więc parser czyta je po kolei i pomija te, których bit jest wyłączony
(`odczytajDaneBiezni` w `TreadmillData.swift`).

Obsłużone bity flag:

| Bit | Pole | Rozmiar | Skala |
|---|---|---|---|
| 0 | prędkość chwilowa *(odwrotny: 0 = pole obecne)* | uint16 | ÷100 → km/h |
| 1 | prędkość średnia | uint16 | ÷100 |
| 2 | dystans całkowity | uint24 | metry |
| 3 | nachylenie + kąt rampy | int16 ×2 | ÷10 |
| 4 | wzniesienie w górę / w dół | uint16 ×2 | ÷10 |
| 5 | tempo chwilowe | uint8 | ÷10 |
| 6 | tempo średnie | uint8 | ÷10 |
| 7 | kalorie + kcal/h + kcal/min | uint16, uint16, uint8 | wartości `0xFFFF` / `0xFF` = brak danych |
| 8 | tętno | uint8 | bpm (0 = brak pasa) |
| 9 | MET | uint8 | ÷10 |
| 10 | czas treningu | uint16 | sekundy |
| 11 | czas pozostały | uint16 | sekundy |
| 12 | siła na pasie + moc | int16 ×2 | N / W |

Wszystkie liczby są **little-endian** — młodszy bajt pierwszy (`ByteReader.swift`).
Nachylenie może być ujemne, więc czytane jest jako liczba ze znakiem (uzupełnienie do dwóch).

### Sterowanie (`0x2AD9`)

FTMS wymaga, żeby najpierw *poprosić o kontrolę* — dopiero potem bieżnia przyjmie komendy
(`Commands.swift`).

| Komenda | Bajty | Znaczenie |
|---|---|---|
| Request Control | `00` | przejęcie kontroli nad maszyną, wysyłane raz po połączeniu |
| Start / Resume | `07` | start pasa |
| Stop | `08 01` | zatrzymanie |
| Pause | `08 02` | pauza |
| Set Target Speed | `02 LL HH` | prędkość ×100, little-endian (np. 6,0 km/h → `02 58 02`) |

Bieżnia odpowiada ramką `80 <komenda> <wynik>`:
`01` OK, `02` nieobsługiwane, `03` zły parametr, `04` brak kontroli, `05` poza zakresem.

### Wykrywanie możliwości (`0x2ACC`)

Zamiast zakładać, co bieżnia potrafi, aplikacja odczytuje mapę bitową i dopiero na jej podstawie
pokazuje kafelki i strzałki prędkości w interfejsie (`Features.swift`).

Przykład z testowanego urządzenia — `c4 56 00 00 0f 00 00 00`:

- nadaje (`0x000056C4`): dystans, liczba kroków, opór, kalorie, tętno, czas, moc
- da się ustawić (`0x0000000F`): prędkość, nachylenie, opór, moc

### Kanał Fitshow (`0xFFF1`)

Prosta ramka z ogranicznikami i sumą kontrolną XOR (`FitshowFrame.swift`):

```
02 51 03 3c 00 13 00 0d 00 09 00 00 00 00 00 79 03
│  │  │  └─┬─┘ └─┬─┘ └─┬─┘ └─┬─┘ └───┬────┘ │  └─ ETX, koniec ramki
│  │  │    │     │     │     │       │      └─ suma kontrolna (XOR bajtów środka)
│  │  │    │     │     │     │       └─ 5 zer: miejsce na tętno i nachylenie
│  │  │    │     │     │     └─ kalorie ×0,1 → 0,9 kcal
│  │  │    │     │     └─ dystans: 13 m
│  │  │    │     └─ czas: 19 s
│  │  │    └─ prędkość ×0,1 → 6,0 km/h
│  │  └─ status maszyny
│  └─ typ ramki (zawsze 0x51)
└─ STX, początek ramki
```

Krótsza ramka (`status 0x02`) niesie cyfrę odliczania przed startem: `02 51 02 05 56 03` → "5".

Kiedy dostępne są oba kanały, FTMS jest źródłem podstawowym, a z Fitshow brane są tylko
dokładne kalorie (ułamkowe) i odliczanie — czyli to, czego FTMS w tym modelu nie podaje.

---

## 3. Co robi aplikacja

- **Automatyczne łączenie** — skan po usłudze `0x1826`, łączenie z pierwszym znalezionym urządzeniem,
  ponowna próba co 2 s po rozłączeniu.
- **Podgląd na żywo** — kafelki z prędkością, dystansem, czasem, kaloriami, tempem, MET, tętnem, mocą;
  pokazywane są tylko te metryki, które urządzenie faktycznie nadaje.
- **Sterowanie** — start, stop, prędkość +/- w granicach zwróconych przez `0x2AD4`.
- **Licznik sesji** — trening podzielony na segmenty (bieżnia zeruje swoje liczniki po każdym stopie),
  aplikacja je sumuje, więc pauza nie kasuje wyniku.
- **Zapis treningu** — po zakończeniu powstają dwa pliki w `~/treningi/`:
  `.tcx` (format Garmin Training Center, do importu w Stravie) i `.json` z podsumowaniem do historii w aplikacji.

### Zrzut ekranu

![Interfejs aplikacji](https://i.imgur.com/siYGcRq.png)

Ciemny interfejs bez paska tytułu, kafelki metryk pokazywane dynamicznie — tylko te, które bieżnia nadaje.

### Struktura projektu

```
Sources/Bieznia/
├── BLE/
│   ├── UUIDs.swift           identyfikatory usług i charakterystyk
│   ├── ByteReader.swift      odczyt little-endian z bufora
│   ├── Commands.swift        komendy wysyłane do bieżni i kody odpowiedzi
│   ├── Features.swift        dekodowanie mapy możliwości (0x2ACC)
│   ├── TreadmillData.swift   parser ramki danych FTMS (0x2ACD)
│   ├── FitshowFrame.swift    parser ramki producenta (0xFFF1)
│   ├── TrainingStatus.swift  fazy treningu (0x2AD3)
│   └── TreadmillClient.swift połączenie, stan, logika sesji
├── Export.swift              zapis TCX + JSON, historia treningów
└── UI/                       interfejs SwiftUI
```

## Wymagania i uruchomienie

- macOS 13 lub nowszy
- **Swift 5.10+** — [pobierz instalator ze swift.org](https://www.swift.org/install/macos/)
  (alternatywnie [Xcode z App Store](https://apps.apple.com/app/xcode/id497799835), który zawiera Swift w komplecie)
- bieżnia z Bluetooth LE wspierająca FTMS

Sprawdzenie, czy Swift jest już w systemie:

```bash
swift --version
```

```bash
./build-app.sh          # buduje i instaluje ~/Applications/Bieznia.app
open ~/Applications/Bieznia.app
```

Skrypt tworzy pakiet `.app` razem z `Info.plist` — wpis `NSBluetoothAlwaysUsageDescription` jest konieczny,
inaczej macOS nie da aplikacji dostępu do Bluetooth. Podpis to podpis lokalny (*ad-hoc*).

Sam `swift build && swift run` też zadziała, ale jako goły plik wykonywalny — system może wtedy odmówić dostępu do Bluetooth.

## Uwagi

Projekt testowany na jednym modelu bieżni. Parser FTMS jest zgodny ze specyfikacją Bluetooth SIG,
więc powinien działać z innymi urządzeniami, natomiast kanał Fitshow (`0xFFF0`) jest specyficzny dla producenta.

## Licencja

[MIT](LICENSE) — rób z tym co chcesz, bez gwarancji.
