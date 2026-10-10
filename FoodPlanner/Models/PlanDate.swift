import Foundation

/// Day keys and week boundaries for the meal planner. Days are keyed `yyyy-MM-dd` in the user's own calendar, so a
/// meal planned for Tuesday stays on Tuesday whatever the time zone or daylight-saving changes. Weeks start on
/// Monday (DEC-8). Foundation-only.
enum PlanDate {
    /// ISO-8601 calendar with Monday as the first weekday, in the current time zone.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    /// "2026-10-05" for the day containing `date`.
    static func key(for date: Date, calendar: Calendar = calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The start of the day for a `yyyy-MM-dd` key, or nil if the key is malformed or not a real date.
    static func date(forKey key: String, calendar: Calendar = calendar) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        // Reject overflow like "2026-02-31", which `Calendar` would quietly roll into March.
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        return check.year == year && check.month == month && check.day == day ? date : nil
    }

    /// The Monday (at the start of the day) of the week containing `date`.
    static func startOfWeek(containing date: Date, calendar: Calendar = calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)  // 1 = Sunday ... 7 = Saturday
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }

    /// The seven days (Monday first) of the week containing `date`, as start-of-day dates.
    static func days(ofWeekContaining date: Date, calendar: Calendar = calendar) -> [Date] {
        let monday = startOfWeek(containing: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// The seven day keys of that week, Monday first.
    static func keys(ofWeekContaining date: Date, calendar: Calendar = calendar) -> [String] {
        days(ofWeekContaining: date, calendar: calendar).map { key(for: $0, calendar: calendar) }
    }

    /// Moves by whole weeks (negative for earlier), keeping the start-of-day.
    static func shifted(_ date: Date, byWeeks weeks: Int, calendar: Calendar = calendar) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }
}
