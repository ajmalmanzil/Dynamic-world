import IslandCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var query = ""

    var body: some View {
        Form {
            Section {
                ForEach(IslandTab.allCases) { tab in
                    let isOn = settings.isEnabled(tab)
                    Toggle(isOn: Binding(get: { isOn }, set: { settings.setEnabled(tab, $0) })) {
                        Label {
                            Text(tab.title)
                        } icon: {
                            StreamlineIconView(icon: tab.icon, size: 14)
                        }
                    }
                    // Keep at least one feature on.
                    .disabled(isOn && settings.enabledTabs.count == 1)
                }
            } header: {
                Text("Features")
            } footer: {
                Text("Turned-off features disappear from the island.")
            }

            Section {
                ForEach(settings.cities) { city in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(city.name)
                            Text("\(city.timeZoneID) · \(WorldClock.offsetDescription(from: .current, to: city.timeZone, at: Date()))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) { settings.removeCity(city) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove")
                    }
                }
                .onMove(perform: settings.moveCities)

                TextField("Add a city (e.g. London, Tokyo)", text: $query)
                ForEach(CitySearch.search(query, limit: 8)) { city in
                    Button {
                        settings.addCity(city)
                        query = ""
                    } label: {
                        HStack {
                            Text(city.name)
                            Spacer()
                            Text(city.timeZoneID).foregroundStyle(.secondary)
                            Image(systemName: "plus.circle")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("World clocks")
            } footer: {
                Text("The first \(SettingsStore.maxVisibleCities) cities appear in the island. Drag to reorder.")
            }

            Section("Clock") {
                Picker("Dot color", selection: $settings.dotColor) {
                    ForEach(DotColor.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("General") {
                Toggle("Show on external displays", isOn: $settings.showOnExternalDisplays)
                Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.setLaunchAtLogin($0) }))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 640)
    }
}
