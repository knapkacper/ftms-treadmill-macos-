import Foundation
import CoreBluetooth


struct Capabilities {
    var hasFTMS = false 
    var hasControl = false
    var hasFitshow = false

    var opis: String {
        let kanaly = [hasFTMS ? "FTMS" : nil, hasFitshow ? "Fitshow" : nil]
        let tekst = kanaly.compactMap { $0 }.joined(separator: " + ")

        return tekst.isEmpty ? "No data" : tekst
    }
}

final class Treadmill: NSObject, ObservableObject {

    enum Status: String {
        case off = "Bluetooth is disabled"
        case unauthorized = "Not authorized"
        case idle = "Not connected"
        case scanning = "Scanning"
        case connecting = "Connecting"
        case connected = "Connected"
    }
    /// @Published == kazda zmiana == automat zmiana frontu
    @Published private(set) var status: Status = .idle
    @Published private(set) var deviceName = "no name"
    @Published private(set) var capabilities = Capabilities()
    @Published private(set) var features = Features()
    @Published private(set) var hasControl = false

    @Published private(set) var current = TreadmillData()
    
    @Published private(set) var samples: [TreadmillData] = []
    
    @Published private(set) var trainingStatus: TrainingStatus = .idle
    @Published private(set) var log: [String] = []

    @Published private(set) var targetSpeed: Double = 0

    @Published private(set) var minSpeed: Double = 1.0
    @Published private(set) var maxSpeed: Double = 6.0
    @Published private(set) var speedStep: Double = 0.1

    private var central: CBCentralManager!
    private var peripheral: CBPerpheral?
    private var controlPoint: CBCharacteristic?

    var isConnected: Bool { status == .connected }

    override init() {
        super.init()














































