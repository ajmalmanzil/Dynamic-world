import IslandCore
import SwiftUI

struct MeetingsTab: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        switch calendar.access {
        case .notDetermined:
            prompt(text: "See today's meetings from Apple Calendar.", button: "Allow Calendar Access") {
                calendar.requestAccess()
            }
        case .denied:
            prompt(text: "Calendar access is off. Turn on Dynamic Island under Privacy & Security › Calendars.",
                   button: "Open Privacy Settings") {
                calendar.openPrivacySettings()
            }
        case .granted:
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let upcoming = MeetingSchedule.upcomingToday(calendar.todaysMeetings, now: context.date)
                if upcoming.isEmpty {
                    VStack {
                        Spacer()
                        Text("No more meetings today").font(.system(size: 12)).opacity(0.45)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, meeting in
                                MeetingRow(meeting: meeting, now: context.date, isNext: index == 0) {
                                    calendar.open(meeting)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
        }
    }

    private func prompt(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Text(text).font(.system(size: 12)).opacity(0.7).multilineTextAlignment(.center)
            Button(button, action: action).controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let now: Date
    let isNext: Bool
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        let status = MeetingSchedule.status(of: meeting, now: now)
        let color = meeting.calendarColor.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? .blue
        let time = "\(WorldClock.timeString(meeting.start, in: .current))–\(WorldClock.timeString(meeting.end, in: .current))"

        HStack(spacing: 10) {
            Capsule().fill(color).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.system(size: 13, weight: isNext ? .semibold : .regular)).lineLimit(1)
                Text([time, meeting.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 10)).opacity(0.5).lineLimit(1)
            }
            Spacer()
            Text(status.label)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(statusColor(status))
            if meeting.joinURL != nil {
                Button(action: open) {
                    Label("Join", systemImage: "video.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(isNext ? 0.1 : (hovering ? 0.06 : 0.03))))
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .onHover { hovering = $0 }
        .help(meeting.joinURL != nil ? "Join call" : "Open in Calendar")
    }

    private func statusColor(_ status: MeetingStatus) -> Color {
        switch status {
        case .inProgress: return .green
        case .upcoming(let minutes) where minutes <= 10: return .orange
        case .upcoming: return .white.opacity(0.6)
        }
    }
}
