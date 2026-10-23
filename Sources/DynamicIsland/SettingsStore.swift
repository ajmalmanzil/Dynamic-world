import IslandCore
import ServiceManagement
import SwiftUI

enum DotColor: String, CaseIterable, Identifiable {
    case white, amber, green, cyan
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .white: return .white
        case .amber: return Color(red: 1.0, green: 0.72, blue: 0.2)
        case .green: return Color(red: 0.3, green: 1.0, blue: 0.45)
        case .cyan: return Color(red: 0.35, green: 0.85, blue: 1.0)
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let maxVisibleCities = 3

    @Published var cities: [City] { didSet { saveCities() } }
    @Published var dotColor: DotColor { didSet { defaults.set(dotColor.rawValue, forKey: Keys.dotColor) } }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults
    private enum Keys {
        static let cities = "cities", dotColor = "dotColor"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.cities),
           let saved = try? JSONDecoder().decode([City].self, from: data) {
            cities = saved
        } else {
            cities = [.newDelhi]
        }
        dotColor = DotColor(rawValue: defaults.string(forKey: Keys.dotColor) ?? "") ?? .white
    }

    func addCity(_ city: City) {
        guard !cities.contains(city) else { return }
        cities.append(city)
    }

    func removeCity(_ city: City) {
        cities.removeAll { $0 == city }
    }

    func moveCities(from source: IndexSet, to destination: Int) {
        cities.move(fromOffsets: source, toOffset: destination)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func saveCities() {
        defaults.set(try? JSONEncoder().encode(cities), forKey: Keys.cities)
    }
}
