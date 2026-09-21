import SwiftUI
import AppKit

final class WidokStan: ObservableObject {
    @Published var pokazHistorie = false
    @Published var ostatniePodsumowanie: WorkoutSummary?
    @Published var treningi: [WorkoutSummary] = []
}


final class Hover: ObservableObject {
    @Published var aktywny = false
}


struct OknoBezPaska: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let widok = NSView()
        DispatchQueue.main.async {
            guard let okno = widok.window else { return }
            okno.isOpaque = true
            okno.backgroundColor = .black
            okno.titlebarAppearsTransparent = true
            okno.titleVisibility = .hidden
            okno.styleMask.insert(.fullSizeContentView)
            okno.isMovableByWindowBackground = true
        }
        return widok
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}


struct ContentView: View {
    @EnvironmentObject var t: Treadmill
    @StateObject private var stan = WidokStan()

    var body: some View {
        VStack(spacing: 0) {
            PasekStanu()
            Spacer(minLength: 0)
            WidokTreningu()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .background(OknoBezPaska())
        .environmentObject(stan)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $stan.pokazHistorie) {
            WidokHistorii { stan.pokazHistorie = false }
                .environmentObject(stan)
        }
    }
}


enum Kolory {
    static let przygaszony = Color.white.opacity(0.45)
    static let ledwo = Color.white.opacity(0.10)
}


struct SubtelnyPrzycisk: View {
    let tytul: String
    let akcja: () -> Void
    @StateObject private var hover = Hover()

    var body: some View {
        Button(action: akcja) {
            Text(tytul)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.white.opacity(hover.aktywny ? 1 : 0.06))
                .foregroundStyle(hover.aktywny ? Color.black : Color.white.opacity(0.35))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover.aktywny = $0 }
        .animation(.easeOut(duration: 0.15), value: hover.aktywny)
    }
}


struct PasekStanu: View {
    @EnvironmentObject var t: Treadmill
    @EnvironmentObject var stan: WidokStan

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(t.isConnected ? Color.white : Kolory.ledwo)
                .frame(width: 7, height: 7)

            Text(t.isConnected ? t.deviceName : t.status.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(t.isConnected ? .white : Kolory.przygaszony)

            if t.isConnected {
                Text(t.capabilities.opis)
                    .font(.system(size: 11))
                    .foregroundStyle(Kolory.przygaszony)
            }

            Spacer()

            SubtelnyPrzycisk(tytul: "History") { stan.pokazHistorie = true }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }
}


struct WidokTreningu: View {
    @EnvironmentObject var t: Treadmill
    @EnvironmentObject var stan: WidokStan

    var body: some View {
        VStack(spacing: 28) {
            Zegar()
            Sterowanie()
        }
        .padding(.horizontal, 28)
        .sheet(item: $stan.ostatniePodsumowanie) { trening in
            Podsumowanie(trening: trening) { stan.ostatniePodsumowanie = nil }
                .environmentObject(stan)
        }
    }
}


struct Zegar: View {
    @EnvironmentObject var t: Treadmill

    var body: some View {
        HStack(alignment: .center, spacing: 40) {
            DuzaWartosc(
                tytul: "Distance",
                wartosc: String(t.sesja.dystans),
                jednostka: "m"
            )

            VStack(spacing: 6) {
                if t.trainingStatus == .preWorkout, let odliczanie = t.current.countDown, odliczanie > 0 {
                    Text("\(odliczanie)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text(String(format: "%02d:%02d", t.sesja.czas / 60, t.sesja.czas % 60))
                        .font(.system(size: 70, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                Text(t.trainingStatus.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Kolory.przygaszony)
            }
            .frame(minWidth: 210)

            DuzaWartosc(
                tytul: "Calories",
                wartosc: String(format: "%.1f", t.sesja.kcal),
                jednostka: "kcal"
            )
        }
        .frame(maxWidth: .infinity)
    }
}


struct DuzaWartosc: View {
    let tytul: String
    let wartosc: String
    let jednostka: String

    var body: some View {
        VStack(spacing: 6) {
            Text(tytul.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Kolory.przygaszony)

            Text(wartosc)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(jednostka)
                .font(.system(size: 10))
                .foregroundStyle(Kolory.przygaszony)
        }
        .frame(minWidth: 110)
    }
}


struct Sterowanie: View {
    @EnvironmentObject var t: Treadmill
    @EnvironmentObject var stan: WidokStan

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("TARGET")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Kolory.przygaszony)

                HStack(spacing: 20) {
                    Strzalka(kierunek: "chevron.left") { t.speedDown() }

                    Text(String(format: "%.1f", t.targetSpeed))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Strzalka(kierunek: "chevron.right") { t.speedUp() }
                }

                Text("km/h")
                    .font(.system(size: 10))
                    .foregroundStyle(Kolory.przygaszony)

                Text(String(format: "current %.1f km/h", t.current.speed))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Kolory.przygaszony)
                    .padding(.top, 8)
            }

            VStack(spacing: 12) {
                if t.trainingStatus.isRunning {
                    PrzyciskAkcji(tytul: "STOP", glowny: true) { t.stop() }
                } else {
                    PrzyciskAkcji(tytul: t.sesja.maDane ? "RESUME" : "START", glowny: true) { t.start() }
                }

                if t.sesja.maDane {
                    PrzyciskAkcji(tytul: t.konczenie ? "STOPPING..." : "FINISH", glowny: false) {
                        t.zakonczTrening { sesja in
                            stan.ostatniePodsumowanie = Historia.zapisz(sesja)
                        }
                    }
                    .disabled(t.konczenie)
                }
            }
            .frame(width: 360)
        }
        .frame(maxWidth: .infinity)
        .opacity(t.hasControl ? 1 : 0.4)
        .disabled(!t.hasControl)
    }
}


struct Strzalka: View {
    let kierunek: String
    let akcja: () -> Void

    var body: some View {
        Button(action: akcja) {
            Image(systemName: kierunek)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


struct PrzyciskAkcji: View {
    let tytul: String
    let glowny: Bool
    let akcja: () -> Void
    @StateObject private var hover = Hover()

    var body: some View {
        Button(action: akcja) {
            Text(tytul)
                .font(.system(size: glowny ? 14 : 12, weight: .bold))
                .tracking(1.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, glowny ? 15 : 12)
                .background(Color.white.opacity(hover.aktywny ? 0.12 : 0))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.aktywny = $0 }
        .animation(.easeOut(duration: 0.15), value: hover.aktywny)
    }
}


struct Podsumowanie: View {
    let trening: WorkoutSummary
    let zamknij: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("WORKOUT COMPLETE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white)

            HStack(spacing: 34) {
                PoleWyniku(tytul: "Time", wartosc: trening.czasSformatowany)
                PoleWyniku(tytul: "Distance", wartosc: "\(trening.distance) m")
                PoleWyniku(tytul: "Calories", wartosc: String(format: "%.1f", trening.kcal))
                PoleWyniku(tytul: "Avg speed", wartosc: String(format: "%.1f", trening.avgSpeed))
                PoleWyniku(tytul: "Max", wartosc: String(format: "%.1f", trening.maxSpeed))
            }

            Text(trening.tcxFile)
                .font(.system(size: 10))
                .foregroundStyle(Kolory.przygaszony)
                .textSelection(.enabled)

            Button(action: zamknij) {
                Text("CLOSE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(width: 560)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}


struct PoleWyniku: View {
    let tytul: String
    let wartosc: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tytul)
                .font(.system(size: 10))
                .foregroundStyle(Kolory.przygaszony)
            Text(wartosc)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}


struct WidokHistorii: View {
    let zamknij: () -> Void
    @EnvironmentObject var stan: WidokStan

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HISTORY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.white)
                Spacer()
                SubtelnyPrzycisk(tytul: "Close", akcja: zamknij)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 18)

            ScrollView {
                VStack(spacing: 5) {
                    HStack {
                        Text("DATE").frame(width: 150, alignment: .leading)
                        Text("TIME").frame(width: 70, alignment: .trailing)
                        Text("DISTANCE").frame(width: 90, alignment: .trailing)
                        Text("KCAL").frame(width: 70, alignment: .trailing)
                        Text("AVG").frame(width: 70, alignment: .trailing)
                        Text("MAX").frame(width: 70, alignment: .trailing)
                        Spacer()
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Kolory.przygaszony)
                    .padding(.bottom, 6)

                    ForEach(stan.treningi) { trening in
                        HStack {
                            Text(trening.dataSformatowana).frame(width: 150, alignment: .leading)
                            Text(trening.czasSformatowany).frame(width: 70, alignment: .trailing)
                            Text("\(trening.distance) m").frame(width: 90, alignment: .trailing)
                            Text(String(format: "%.1f", trening.kcal)).frame(width: 70, alignment: .trailing)
                            Text(String(format: "%.1f", trening.avgSpeed)).frame(width: 70, alignment: .trailing)
                            Text(String(format: "%.1f", trening.maxSpeed)).frame(width: 70, alignment: .trailing)
                            Spacer()
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.vertical, 9)
                    }

                    if stan.treningi.isEmpty {
                        Text("No saved workouts")
                            .font(.system(size: 12))
                            .foregroundStyle(Kolory.przygaszony)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 640, height: 460)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear { stan.treningi = Historia.wczytaj() }
    }
}
