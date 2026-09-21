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


struct Sesja {
    var start: Date?

    var poprzednieCzas = 0
    var poprzednieDystans = 0
    var poprzednieKcal = 0.0

    var segmentCzas = 0
    var segmentDystans = 0
    var segmentKcal = 0.0

    var maxSpeed = 0.0
    var sumaSpeed = 0.0
    var probki = 0

    var czas: Int { poprzednieCzas + segmentCzas }
    var dystans: Int { poprzednieDystans + segmentDystans }
    var kcal: Double { poprzednieKcal + segmentKcal }

    var avgSpeed: Double { probki > 0 ? sumaSpeed / Double(probki) : 0 }

    var maDane: Bool { czas > 2 }
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

    @Published private(set) var status: Status = .idle
    @Published private(set) var deviceName = "no name"
    @Published private(set) var capabilities = Capabilities()
    @Published private(set) var features = Features()
    @Published private(set) var hasControl = false

    @Published private(set) var current = TreadmillData()
    @Published private(set) var sesja = Sesja()

    @Published private(set) var trainingStatus: TrainingStatus = .idle
    @Published private(set) var konczenie = false

    @Published private(set) var targetSpeed: Double = 0

    @Published private(set) var minSpeed: Double = 1.0
    @Published private(set) var maxSpeed: Double = 6.0
    @Published private(set) var speedStep: Double = 0.1

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var controlPoint: CBCharacteristic?

    var isConnected: Bool { status == .connected }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func connect() {
        guard central.state == .poweredOn else { return }
        status = .scanning
        zapisz("szukam biezni")
        central.scanForPeripherals(withServices: [FTMS.service], options: nil)
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    func start() { wyslij(Commands.start, "START") }
    func stop() { wyslij(Commands.stop, "STOP") }

    func zakonczTrening(gotowe: @escaping (Sesja) -> Void) {
        guard !konczenie else { return }
        konczenie = true

        stop()
        poczekajNaZatrzymanie(proba: 0, gotowe: gotowe)
    }

    private func poczekajNaZatrzymanie(proba: Int, gotowe: @escaping (Sesja) -> Void) {
        if trainingStatus == .idle || proba >= 40 {
            zwinSegment()
            let kopia = sesja
            sesja = Sesja()
            targetSpeed = 0
            konczenie = false
            gotowe(kopia)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.poczekajNaZatrzymanie(proba: proba + 1, gotowe: gotowe)
        }
    }

    func setSpeed(_ kmh: Double) {
        let wartosc = min(max(kmh, minSpeed), maxSpeed)
        targetSpeed = wartosc
        wyslij(Commands.speed(wartosc), String(format: "predkosc %.1f km/h", wartosc))
    }

    func speedUp() { setSpeed((targetSpeed > 0 ? targetSpeed : current.speed) + speedStep) }
    func speedDown() { setSpeed((targetSpeed > 0 ? targetSpeed : current.speed) - speedStep) }

    func resetSession() {
        sesja = Sesja()
    }

    private func wyslij(_ bajty: [UInt8], _ opis: String) {
        guard let charakterystyka = controlPoint, let peripheral else {
            zapisz("nie polaczono, komenda \(opis) pominieta")
            return
        }
        zapisz("-> \(opis)")
        peripheral.writeValue(Data(bajty), for: charakterystyka, type: .withResponse)
    }

    private func zapisz(_ tekst: String) {
        print("[bieznia] \(tekst)")
    }

    private func zaktualizujSesje() {
        if sesja.start == nil, current.speed > 0 { sesja.start = Date() }

        if targetSpeed == 0, current.speed > 0 {
            targetSpeed = max(minSpeed, current.speed)
        }

        sesja.segmentCzas = max(sesja.segmentCzas, current.workingTime ?? 0)
        sesja.segmentDystans = max(sesja.segmentDystans, current.distance ?? 0)
        sesja.segmentKcal = max(sesja.segmentKcal, current.kcalPrecise ?? 0)
        sesja.maxSpeed = max(sesja.maxSpeed, current.speed)

        if current.speed > 0 {
            sesja.sumaSpeed += current.speed
            sesja.probki += 1
        }
    }

    private func zwinSegment() {
        sesja.poprzednieCzas += sesja.segmentCzas
        sesja.poprzednieDystans += sesja.segmentDystans
        sesja.poprzednieKcal += sesja.segmentKcal

        sesja.segmentCzas = 0
        sesja.segmentDystans = 0
        sesja.segmentKcal = 0

        targetSpeed = 0
    }

    private func sklejFitshow(_ ramka: FitshowFrame) {
        if capabilities.hasFTMS {
            if let k = ramka.kcal { current.kcalPrecise = k }
            current.countDown = ramka.countDown
        } else {
            current.date = Date()
            if let v = ramka.speed { current.speed = v }
            current.distance = ramka.distance
            current.workingTime = ramka.time
            current.kcalPrecise = ramka.kcal
            current.kcal = ramka.kcal.map { Int($0) }
            current.countDown = ramka.countDown
            zaktualizujSesje()
        }
    }
}


extension Treadmill: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = .idle
            zapisz("bluetooth gotowy")
            connect()
        case .poweredOff:
            status = .off
        case .unauthorized:
            status = .unauthorized
            zapisz("system odmowil dostepu do bluetooth")
        default:
            status = .idle
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard self.peripheral == nil else { return }

        let nazwa = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "bez nazwy"

        zapisz("znaleziono \(nazwa), sygnal \(RSSI) dBm")
        deviceName = nazwa
        self.peripheral = peripheral
        status = .connecting

        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = .connected
        zapisz("polaczono")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        zapisz("nie udalo sie polaczyc: \(error?.localizedDescription ?? "nieznany blad")")
        posprzataj()
        sprobujPonownie()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        zapisz("rozlaczono")
        posprzataj()
        sprobujPonownie()
    }

    private func sprobujPonownie() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.peripheral == nil else { return }
            self.connect()
        }
    }

    private func posprzataj() {
        peripheral = nil
        controlPoint = nil
        hasControl = false
        capabilities = Capabilities()
        features = Features()
        status = .idle
        deviceName = "no name"
    }
}


extension Treadmill: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for usluga in peripheral.services ?? [] {
            switch usluga.uuid {
            case FTMS.service, Fitshow.service:
                peripheral.discoverCharacteristics(nil, for: usluga)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for ch in service.characteristics ?? [] {
            switch ch.uuid {

            case FTMS.tredmillData:
                capabilities.hasFTMS = true
                peripheral.setNotifyValue(true, for: ch)

            case FTMS.machineStatus:
                peripheral.setNotifyValue(true, for: ch)

            case FTMS.trainingStatus:
                peripheral.setNotifyValue(true, for: ch)
                peripheral.readValue(for: ch)

            case FTMS.startStop:
                capabilities.hasControl = true
                controlPoint = ch
                peripheral.setNotifyValue(true, for: ch)
                wyslij(Commands.requestControl, "przejmuje kontrole")

            case FTMS.speedRange, FTMS.feature:
                peripheral.readValue(for: ch)

            case Fitshow.data:
                capabilities.hasFitshow = true
                peripheral.setNotifyValue(true, for: ch)

            default:
                break
            }
        }

        zapisz("wykryte kanaly: \(capabilities.opis)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let dane = characteristic.value else { return }

        switch characteristic.uuid {

        case FTMS.tredmillData:
            guard let probka = odczytajDaneBiezni(dane) else { return }

            let zapamietaneKcal = current.kcalPrecise
            let zapamietaneOdliczanie = current.countDown

            current = probka

            if capabilities.hasFitshow {
                current.kcalPrecise = zapamietaneKcal
                current.countDown = zapamietaneOdliczanie
            }
            zaktualizujSesje()

        case Fitshow.data:
            guard let ramka = odczytajRamkeFitshow(dane) else { return }
            sklejFitshow(ramka)

        case FTMS.trainingStatus:
            let b = [UInt8](dane)
            guard b.count >= 2, let faza = TrainingStatus(rawValue: b[1]) else { return }
            if faza != trainingStatus {
                if faza == .idle { zwinSegment() }
                trainingStatus = faza
                zapisz("faza: \(faza.label)")
            }

        case FTMS.feature:
            features = decodeFeatures(dane)
            zapisz(features.canSetSpeed ? "mozna ustawiac predkosc" : "tylko odczyt")

        case FTMS.startStop:
            let b = [UInt8](dane)
            guard b.count >= 3, b[0] == 0x80 else { return }
            let wynik = OdpowiedziBiezni(rawValue: b[2])?.opis ?? "kod \(b[2])"
            zapisz("<- komenda 0x\(String(format: "%02X", b[1])): \(wynik)")
            if b[1] == 0x00 && b[2] == 0x01 { hasControl = true }

        case FTMS.machineStatus:
            let zdarzenia: [UInt8: String] = [
                0x01: "reset", 0x02: "zatrzymana przez uzytkownika", 0x03: "pauza",
                0x04: "start", 0x05: "zmiana predkosci", 0x0D: "trening zakonczony"
            ]
            if let kod = [UInt8](dane).first {
                zapisz("<- bieznia: \(zdarzenia[kod] ?? "zdarzenie 0x\(String(format: "%02X", kod))")")
            }

        case FTMS.speedRange:
            var reader = ByteReader(dane)
            minSpeed = Double(reader.uint16()) / 100
            maxSpeed = Double(reader.uint16()) / 100
            speedStep = Double(reader.uint16()) / 100
            zapisz(String(format: "zakres: %.1f-%.1f km/h, krok %.1f", minSpeed, maxSpeed, speedStep))

        default:
            break
        }
    }
}
