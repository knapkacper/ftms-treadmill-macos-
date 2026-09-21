///to co my wysylamy do bierzni 

import Foundation 

enum Commands { 

    static let requestControl: [UInt8] = [0x00]

    static let start: [UInt8] = [0x07]

    static let stop: [UInt8] = [0x08, 0x01]

    static let pause: [UInt8] = [0x08, 0x02]

    static func speed(_ kmh: Double) -> [UInt8] {
        let raw = UInt16(max(0, (kmh * 100).rounded()))
        return [0x02, UInt8(raw & 0xFF), UInt8(raw >> 8)]
    }
}

/// odpowiedzi od bieznia na nasze komendy

enum OdpowiedziBiezni: UInt8 {
    case ok = 0x01
    case nieobslugiwane = 0x02
    case zlyParametr = 0x03
    case brakKontroli = 0x04
    case pozaZakresem = 0x05

    var opis: String {
        switch self {
            case .ok: return "OK"
            case .nieobslugiwane: return "Not supported"
            case .zlyParametr: return "Invalid parameter"
            case .brakKontroli: return "Control not permitted"
            case .pozaZakresem: return "Out of range"
        }
    }
}
