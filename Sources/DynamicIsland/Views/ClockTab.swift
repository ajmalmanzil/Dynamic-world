import IslandCore
import SwiftUI

/// Draws a grid of on/off dots, LED-style.
struct DotGrid: View {
    var dots: [[Bool]]
    var color: Color
    var dot: CGFloat
    var spacing: CGFloat
    /// Faintly draw the dots that are off, like a real LED panel.
    var showsUnlit = false

    var body: some View {
        let pitch = dot + spacing
        let rows = dots.count, cols = dots.first?.count ?? 0
        Canvas { context, _ in
            for (row, bits) in dots.enumerated() {
                for (col, on) in bits.enumerated() where on || showsUnlit {
                    let rect = CGRect(x: CGFloat(col) * pitch, y: CGFloat(row) * pitch, width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(on ? color : color.opacity(0.09)))
                }
            }
        }
        .frame(width: max(0, CGFloat(cols) * pitch - spacing), height: max(0, CGFloat(rows) * pitch - spacing))
    }
}

/// Renders text with `DotMatrixFont`.
struct DotMatrixText: View {
    var text: String
    var color: Color
    var dot: CGFloat = 5
    var spacing: CGFloat = 2
    var showsUnlit = true
    var glows = true

    var body: some View {
        DotGrid(dots: Self.grid(for: DotMatrixFont.normalize(text)), color: color,
                dot: dot, spacing: spacing, showsUnlit: showsUnlit)
            .shadow(color: glows ? color.opacity(0.45) : .clear, radius: 4)
            .accessibilityLabel(text)
    }

    /// Glyphs laid side by side with one blank column between them.
    private static func grid(for text: String) -> [[Bool]] {
        var rows = Array(repeating: [Bool](), count: DotMatrixFont.rows)
        for (i, character) in text.enumerated() {
            let glyph = DotMatrixFont.glyph(for: character)
            for r in 0..<DotMatrixFont.rows {
                if i > 0 { rows[r].append(false) }
                rows[r] += glyph[r]
            }
        }
        return rows
    }
}

struct ClockTab: View {
    @ObservedObject var settings: SettingsStore

    // Big local clock: 5pt dots → 7 × 7 − 2 = 47pt tall. City rows: 2.5pt dots → 7 × 3.5 − 1 = 23.5pt.
    static let mainClockHeight: CGFloat = 47
    static let cityRowHeight: CGFloat = 23.5
    static let cityRowSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 14
    static let emptyHintHeight: CGFloat = 16

    static func contentHeight(cityCount: Int) -> CGFloat {
        let n = CGFloat(cityCount)
        let cities = cityCount == 0 ? emptyHintHeight : n * cityRowHeight + (n - 1) * cityRowSpacing
        return mainClockHeight + sectionSpacing + cities
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: Self.sectionSpacing) {
                DotMatrixText(text: WorldClock.timeString(context.date, in: .current), color: settings.dotColor.color)

                if settings.cities.isEmpty {
                    Text("Add cities in Settings to see more time zones")
                        .font(.system(size: 11)).opacity(0.5)
                        .frame(height: Self.emptyHintHeight)
                } else {
                    VStack(spacing: Self.cityRowSpacing) {
                        ForEach(settings.cities.prefix(SettingsStore.maxVisibleCities)) { city in
                            CityRow(name: city.name,
                                    time: WorldClock.timeString(context.date, in: city.timeZone),
                                    color: settings.dotColor.color)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

/// Place on the left, its time on the right, same dot size.
private struct CityRow: View {
    let name: String
    let time: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            DotMatrixText(text: String(name.prefix(16)), color: color.opacity(0.75),
                          dot: 2.5, spacing: 1, showsUnlit: false, glows: false)
            Spacer(minLength: 0)
            DotMatrixText(text: time, color: color, dot: 2.5, spacing: 1, showsUnlit: false, glows: false)
        }
        .frame(height: ClockTab.cityRowHeight)
    }
}
