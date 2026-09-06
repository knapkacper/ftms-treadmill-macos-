
import CoreBluetooth


enum FTMS { 
    /// fitnes machine service tag ze jest dane urzadzenie maszyana do cwiczen kategoria rozmowy bluetooth
    static let service = CBUUID(string: "1826")

    /// wysylanie i odbieranie danych z komunikatora
    static let tredmillData = CBUUID(string: "2ACD")

    /// start stop predkosc wysylanie komend do bieznia
    static let startStop = CBUUID(string: "2AD9")

    /// statusy maszyny tupy ktos ja zatrzymal itp 
    static let machineStatus = CBUUID(string: "2ADA")

    /// max wartosci biezni aby wiedziec od ile do ile mozemy ustawic
    static let speedRange = CBUUID(string: "2AD4")

    /// faza trenningu ile / odliczanie /bieg / zwalnianie
    static let trainingStatus = CBUUID(string: "2AD3")

    ///mapa mozliwosci zwracania danych sprzedtu
    static let feature = CBUUID(string: "2ACC")
}

// sprawdzenie kanalu producenta 
enum Fitshow {
    static let service = CBUUID(string: "FFF0")
    static let data = CBUUID(string: "FFF1")
}
