import Foundation

struct TreadmillData {
    var date = Date()

    var speed: Double = 0

    var averageSpeed: Double?

    var distance: Int?
    var inclination: Double?
    var rampAngle: Double?
    var elevationGain: Double?
    var elevationLoss: Double?

    var pace: Double?
    var averagePace: Double?

    var kcal: Int?
    var kcalPerHour: Int?
    var kcalPerMinute: Int?

    var heartRate: Int?
    var met: Double?

    var workingTime: Int?
    var remainingTime: Int?

    var beltForce: Int?
    var power: Int?

    var kcalPrecise: Double?

    var countDown: Int?

    var rawFlags: Int = 0

    var tempoMinNaKm: Double? {
        guard speed > 0 else { return nil }
        return 60 / speed
    }

    var czasSformatowany: String {
        let s = workingTime ?? 0
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}


enum Metryka: String, CaseIterable {
    case speed, averageSpeed, distance, kcal, kcalPerHour
    case heartRate, pace, met, inclination, power

    var nazwa: String {
        switch self {
            case .speed: return "Prędkość"
            case .averageSpeed: return "Średnia prędkość"
            case .distance: return "Odległość"
            case .kcal: return "Kalorie"
            case .kcalPerHour: return "Kalorie na godzinę"
            case .heartRate: return "Tętno"
            case .pace: return "Tempo"
            case .met: return "MET"
            case .inclination: return "Nachylenie"
            case .power: return "Moc"
        }
    }

    var jednostka: String {
        switch self {
            case .speed, .averageSpeed: return "km/h"
            case .distance: return "m"
            case .kcal: return "kcal"
            case .kcalPerHour: return "kcal/h"
            case .heartRate: return "bpm"
            case .pace: return "min/km"
            case .met: return "MET"
            case .inclination: return "%"
            case .power: return "W"
        }
    }

    var naWykresie: Bool {
        switch self {
            case .distance: return false
            default: return true
        }
    }

    var miejscaPoPrzecinku: Int {
        switch self {
            case .speed, .averageSpeed, .met, .inclination, .pace: return 1
            default: return 0
        }
    }
}

extension TreadmillData {
    func wartosc(_ metryka: Metryka) -> Double? {
        switch metryka {
            case .speed: return speed
            case .averageSpeed: return averageSpeed
            case .distance: return distance.map(Double.init)
            case .kcal: return kcalPrecise ?? kcal.map(Double.init)
            case .kcalPerHour: return kcalPerHour.map(Double.init)
            case .heartRate: return heartRate.map(Double.init)
            case .pace: return tempoMinNaKm
            case .met: return met
            case .inclination: return inclination
            case .power: return power.map(Double.init)
        }
    }

    var dostepneMetryki: [Metryka] {
        Metryka.allCases.filter { wartosc($0) != nil }
    }
}

func odczytajDaneBiezni(_ data: Data) -> TreadmillData? {
    var reader = ByteReader(data)
    let flagi = reader.uint16()

    func czyJest(_ bit: Int) -> Bool { flagi & (1 << bit) != 0 }

    var data = TreadmillData()
    data.rawFlags = flagi

    guard !czyJest(0) else { return nil }
    data.speed = Double(reader.uint16()) / 100

    if czyJest(1) { data.averageSpeed = Double(reader.uint16()) / 100 }
    if czyJest(2) { data.distance = reader.uint24() }
    if czyJest(3) {
        data.inclination = Double(reader.int16()) / 10.0
        data.rampAngle = Double(reader.int16()) / 10.0
    }
    if czyJest(4) {
        data.elevationGain = Double(reader.uint16()) / 10.0
        data.elevationLoss = Double(reader.uint16()) / 10.0
    }
    if czyJest(5) { data.pace = Double(reader.uint8()) / 10.0 }
    if czyJest(6) { data.averagePace = Double(reader.uint8()) / 10.0 }
    if czyJest(7) {
        data.kcal = reader.uint16()

        let naGodzine = reader.uint16()
        data.kcalPerHour = naGodzine == 0xFFFF ? nil : naGodzine

        let naMinute = reader.uint8()
        data.kcalPerMinute = naMinute == 0xFF ? nil : naMinute
    }
    if czyJest(8) {
        let tetno = reader.uint8()
        data.heartRate = tetno == 0 ? nil : tetno
    }
    if czyJest(9) { data.met = Double(reader.uint8()) / 10.0 }
    if czyJest(10) { data.workingTime = reader.uint16() }
    if czyJest(11) { data.remainingTime = reader.uint16() }
    if czyJest(12) {
        data.beltForce = reader.int16()
        data.power = reader.int16()
    }

    data.kcalPrecise = data.kcal.map(Double.init)

    return data
}
