import Foundation

struct ByteReader {
    let bytes: [UInt8]
    var index = 0

    init(_ data: Data) { bytes = [UInt8](data) }

    mutating func uint8() -> Int {
        defer { index += 1 }
        return index < bytes.count ? Int(bytes[index]) : 0
    }

    mutating func uint16() -> Int {
        defer { index += 2 }
        guard index + 1 < bytes.count else { return 0 }
        // little-endian: mlodszy bajt PIERWSZY, wiec przesuwamy tylko drugi.
        // `2c 01` = 0x2C | 0x01 << 8 = 0x012C = 300
        return Int(bytes[index]) | Int(bytes[index + 1]) << 8
    }

    mutating func uint24() -> Int {
        defer { index += 3 }
        guard index + 2 < bytes.count else { return 0 }
        return Int(bytes[index]) | Int(bytes[index + 1]) << 8 | Int(bytes[index + 2]) << 16
    }

    /// nachylenie moze byc ujemne u nas jest tania bieznia wiec nie ma 
    mutating func int16() -> Int { 
        let raw = uint16()
        return raw > 0x7FFF ? raw - 0x10000 : raw
    }

    mutating func uint32() -> Int {
        defer { index += 4 } 
        guard index + 3 < bytes.count else { return 0 } 
        return Int(bytes[index]) | Int(bytes[index + 1]) << 8 | Int(bytes[index + 2]) << 16 | Int(bytes[index + 3]) << 24
    }
}

