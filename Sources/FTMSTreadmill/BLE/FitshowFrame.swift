// Pelna ramka, gdy bieznia jedzie:
//
//   02 51 03 3c 00 13 00 0d 00 09 00 00 00 00 00 79 03
//   │  │  │  └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └────┬───┘ │  └─ ETX, koniec ramki
//   │  │  │    │      │      │      │         │     └─ suma kontrolna
//   │  │  │    │      │      │      │         └─ 5 bajtow zawsze zerowych
//   │  │  │    │      │      │      │            (miejsce na tetno i nachylenie,
//   │  │  │    │      │      │      │             ktorych ten model nie ma)
//   │  │  │    │      │      │      └─ kalorie x0,1  → 0,9 kcal
//   │  │  │    │      │      └─ dystans 13 metrow
//   │  │  │    │      └─ czas 19 sekund
//   │  │  │    └─ predkosc x0,1 → 6,0 km/h
//   │  │  └─ status maszyny
//   │  └─ typ ramki (zawsze 0x51)
//   └─ STX, poczatek ramki
//
// Krotsza ramka, gdy bieznia odlicza przed startem:
//
//   02 51 02 05 56 03
//   │  │  │  │  │  └─ ETX
//   │  │  │  │  └─ suma kontrolna
//   │  │  │  └─ cyfra odliczania: 5
//   │  │  └─ status 02 = odliczanie
//   │  └─ typ ramki
//   └─ STX
import Foundation

struct FitshowFrame {
    var status: Int = 0 

    var speed: Double?
    var time: Int?
    var distance: Int?
    var kcal: Double?
    var countDown: Int?
}

func odczytajRamkeFitshow(_ data: Data) -> FitshowFrame? {
    let bytes = [UInt8](data)

    guard bytes.count >= 5, bytes[0] == 0x02, bytes[bytes.count - 1] == 0x03 else {return nil}

    let suma = bytes[1..<(bytes.count - 2)].reduce(UInt8(0)) { $0 ^ $1 }
    guard suma == bytes[bytes.count - 2] else { return nil }

    var ramka = FitshowFrame()
    ramka.status = Int(bytes[2])

    if ramka.status == 0x02 {
        if bytes.count >= 6 { ramka.countDown = Int(bytes[3]) }
        return ramka
    }

    guard bytes.count >= 13 else { return nil }

    func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 }

    ramka.speed = Double(u16(3)) / 10.0
    ramka.time = u16(5)
    ramka.distance = u16(7)
    ramka.kcal = Double(u16(9)) / 10.0

    return ramka
}


























