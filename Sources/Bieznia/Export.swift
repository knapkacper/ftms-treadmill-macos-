import Foundation

struct WorkoutSummary: Codable, Identifiable {
    var id: String
    var date: Date
    var duration: Int
    var distance: Int
    var kcal: Double
    var avgSpeed: Double
    var maxSpeed: Double
    var tcxFile: String

    var czasSformatowany: String {
        String(format: "%02d:%02d", duration / 60, duration % 60)
    }

    var dataSformatowana: String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f.string(from: date)
    }
}

enum Historia {

    static var katalog: URL {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("treningi")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    static func zapisz(_ sesja: Sesja) -> WorkoutSummary? {
        guard sesja.czas > 2 else { return nil }

        let poczatek = sesja.start ?? Date().addingTimeInterval(-Double(sesja.czas))

        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        let nazwa = "trening-\(f.string(from: poczatek))"

        let tcxURL = katalog.appendingPathComponent("\(nazwa).tcx")
        try? zbudujTCX(sesja, poczatek: poczatek)
            .write(to: tcxURL, atomically: true, encoding: .utf8)

        let podsumowanie = WorkoutSummary(
            id: nazwa,
            date: poczatek,
            duration: sesja.czas,
            distance: sesja.dystans,
            kcal: sesja.kcal,
            avgSpeed: sesja.avgSpeed,
            maxSpeed: sesja.maxSpeed,
            tcxFile: tcxURL.path
        )

        let koder = JSONEncoder()
        koder.dateEncodingStrategy = .iso8601
        if let json = try? koder.encode(podsumowanie) {
            try? json.write(to: katalog.appendingPathComponent("\(nazwa).json"))
        }

        return podsumowanie
    }

    static func wczytaj() -> [WorkoutSummary] {
        let pliki = (try? FileManager.default.contentsOfDirectory(
            at: katalog, includingPropertiesForKeys: nil)) ?? []

        let dekoder = JSONDecoder()
        dekoder.dateDecodingStrategy = .iso8601

        return pliki
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> WorkoutSummary? in
                guard let dane = try? Data(contentsOf: url) else { return nil }
                return try? dekoder.decode(WorkoutSummary.self, from: dane)
            }
            .sorted { $0.date > $1.date }
    }

    static func usun(_ trening: WorkoutSummary) {
        try? FileManager.default.removeItem(at: katalog.appendingPathComponent("\(trening.id).json"))
        try? FileManager.default.removeItem(atPath: trening.tcxFile)
    }

    private static func zbudujTCX(_ sesja: Sesja, poczatek: Date) -> String {
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        let koniec = poczatek.addingTimeInterval(Double(sesja.czas))

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase
            xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"
            xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
          <Activities>
            <Activity Sport="Running">
              <Id>\(iso.string(from: poczatek))</Id>
              <Lap StartTime="\(iso.string(from: poczatek))">
                <TotalTimeSeconds>\(sesja.czas)</TotalTimeSeconds>
                <DistanceMeters>\(sesja.dystans)</DistanceMeters>
                <MaximumSpeed>\(String(format: "%.3f", sesja.maxSpeed / 3.6))</MaximumSpeed>
                <Calories>\(Int(sesja.kcal.rounded()))</Calories>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>
                <Track>
                  <Trackpoint>
                    <Time>\(iso.string(from: poczatek))</Time>
                    <DistanceMeters>0</DistanceMeters>
                  </Trackpoint>
                  <Trackpoint>
                    <Time>\(iso.string(from: koniec))</Time>
                    <DistanceMeters>\(sesja.dystans)</DistanceMeters>
                  </Trackpoint>
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
    }
}
