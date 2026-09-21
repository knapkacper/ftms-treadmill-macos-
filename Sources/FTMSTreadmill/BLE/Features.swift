import Foundation

struct Features {

    /// co dana umie zwrocic nie plik jaki porokol tylko jakie dane jestesmy zdolni pokazac front
    var hasAverageSpeed = false
    var hasCadence = false
    var hasTotalDistance = false
    var hasInclination = false       // ja nie mam
    var hasElevationGain = false
    var hasPace = false
    var hasStepCount = false
    var hasResistance = false
    var hasStrideCount = false
    var hasEnergy = false            // kalorie
    var hasHeartRate = false
    var hasMET = false
    var hasElapsedTime = false
    var hasRemainingTime = false
    var hasPower = false
    var hasForceOnBelt = false

    var canSetSpeed = false          // czy pokazujemy strzalki przyspieszania
    var canSetInclination = false
    var canSetResistance = false
    var canSetPower = false

    /// wszystko i niczego nie ukrywac przedwczesnie.is false == nie da sie zmienaic adnych front 
    var isKnown = false
}

/// Twoja bieznia zwraca `c4 56 00 00 0f 00 00 00`:
///
///     mozliwosci = 0x000056C4 = 0101 0110 1100 0100
///                                │ ││ ││    │
///                                │ ││ ││    └─ bit 2  dystans
///                                │ ││ │└────── bit 6  liczba krokow
///                                │ ││ └─────── bit 7  opor
///                                │ │└───────── bit 9  kalorie
///                                │ └────────── bit 10 tetno
///                                └──────────── bit 12 czas, bit 14 moc
///
///     ustawianie = 0x0000000F = predkosc, nachylenie, opor, moc, czas

func decodeFeatures(_ data: Data) -> Features {
    var reader = ByteReader(data)
    let coBiezniaNadaje = reader.uint32()
    let coMoznaUstawic = reader.uint32()

    func czyNadaje(_ bit: Int) -> Bool { coBiezniaNadaje & (1 << bit) != 0 }
    func czyMoznaUstawic(_ bit: Int) -> Bool { coMoznaUstawic & (1 << bit) != 0 }

    var f = Features()
    
    f.hasAverageSpeed = czyNadaje(0)
    f.hasCadence = czyNadaje(1)
    f.hasTotalDistance = czyNadaje(2)
    f.hasInclination = czyNadaje(3)
    f.hasElevationGain = czyNadaje(4)
    f.hasPace = czyNadaje(5)
    f.hasStepCount = czyNadaje(6)
    f.hasResistance = czyNadaje(7)
    f.hasStrideCount = czyNadaje(8)
    f.hasEnergy = czyNadaje(9)
    f.hasHeartRate = czyNadaje(10)
    f.hasMET = czyNadaje(11)
    f.hasElapsedTime = czyNadaje(12)
    f.hasRemainingTime = czyNadaje(13)
    f.hasPower = czyNadaje(14)
    f.hasForceOnBelt = czyNadaje(15)

    f.canSetSpeed = czyMoznaUstawic(0)
    f.canSetInclination = czyMoznaUstawic(1)
    f.canSetResistance = czyMoznaUstawic(2)
    f.canSetPower = czyMoznaUstawic(3)

    f.isKnown = true

    return f 
}
























