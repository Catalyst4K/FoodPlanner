import Foundation
import Testing

@testable import FoodPlanner

@Suite("PlanDate")
struct PlanDateTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar
    }

    private func day(_ key: String, _ calendar: Calendar) throws -> Date {
        try #require(PlanDate.date(forKey: key, calendar: calendar))
    }

    // MARK: - Keys

    @Test func keysRoundTrip() throws {
        let utc = calendar("UTC")
        for key in ["2026-10-05", "2026-01-01", "2024-02-29", "1999-12-31"] {
            let date = try day(key, utc)
            #expect(PlanDate.key(for: date, calendar: utc) == key)
        }
    }

    @Test func malformedOrImpossibleKeysAreRejected() {
        let utc = calendar("UTC")
        for key in [
            "", "2026", "2026-1-5", "2026-10-5", "26-10-05", "abcd-ef-gh", "2026-13-01", "2026-00-10",
            "2026-02-30", "2026-02-29", "2026-04-31", "2026-10-05-01", "2026/10/05", " 2026-10-05",
        ] {
            #expect(PlanDate.date(forKey: key, calendar: utc) == nil, "\(key)")
        }
        #expect(PlanDate.date(forKey: "2024-02-29", calendar: utc) != nil)
    }

    @Test func theSameInstantIsDifferentDaysInDifferentZones() throws {
        // 23:30 UTC on 5 Oct is already 6 Oct in Auckland (UTC+13 in October) and still 5 Oct in New York.
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-05T23:30:00Z"))
        #expect(PlanDate.key(for: instant, calendar: calendar("UTC")) == "2026-10-05")
        #expect(PlanDate.key(for: instant, calendar: calendar("Pacific/Auckland")) == "2026-10-06")
        #expect(PlanDate.key(for: instant, calendar: calendar("America/New_York")) == "2026-10-05")
    }

    // MARK: - Weeks (Monday start, DEC-8)

    @Test func weekStartsOnMondayWhateverDayYouStartFrom() throws {
        let utc = calendar("UTC")
        // 2026-10-05 is a Monday.
        for key in ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-09", "2026-10-11"] {
            let monday = PlanDate.startOfWeek(containing: try day(key, utc), calendar: utc)
            #expect(PlanDate.key(for: monday, calendar: utc) == "2026-10-05", "\(key)")
        }
        let nextMonday = PlanDate.startOfWeek(containing: try day("2026-10-12", utc), calendar: utc)
        #expect(PlanDate.key(for: nextMonday, calendar: utc) == "2026-10-12")
    }

    @Test func aWeekHasSevenConsecutiveKeysMondayFirst() throws {
        let utc = calendar("UTC")
        let keys = PlanDate.keys(ofWeekContaining: try day("2026-10-08", utc), calendar: utc)
        #expect(
            keys == ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11"])
    }

    @Test func weeksCanSpanTheNewYear() throws {
        let utc = calendar("UTC")
        let keys = PlanDate.keys(ofWeekContaining: try day("2026-01-01", utc), calendar: utc)  // a Thursday
        #expect(keys.first == "2025-12-29")
        #expect(keys.last == "2026-01-04")
        #expect(keys.count == 7 && Set(keys).count == 7)
    }

    @Test func weeksCanSpanALeapDay() throws {
        let utc = calendar("UTC")
        let keys = PlanDate.keys(ofWeekContaining: try day("2024-02-28", utc), calendar: utc)
        #expect(
            keys == ["2024-02-26", "2024-02-27", "2024-02-28", "2024-02-29", "2024-03-01", "2024-03-02", "2024-03-03"])
    }

    @Test func daylightSavingChangesDoNotDropOrRepeatDays() throws {
        let london = calendar("Europe/London")
        // Clocks go back on 25 Oct 2026 (a 25-hour day) and forward on 29 Mar 2026 (a 23-hour day).
        let autumn = PlanDate.keys(ofWeekContaining: try day("2026-10-22", london), calendar: london)
        #expect(
            autumn == [
                "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25",
            ])
        let spring = PlanDate.keys(ofWeekContaining: try day("2026-03-27", london), calendar: london)
        #expect(
            spring == [
                "2026-03-23", "2026-03-24", "2026-03-25", "2026-03-26", "2026-03-27", "2026-03-28", "2026-03-29",
            ])
        // And the week after a change starts on the right Monday.
        let after = PlanDate.startOfWeek(containing: try day("2026-10-28", london), calendar: london)
        #expect(PlanDate.key(for: after, calendar: london) == "2026-10-26")
    }

    @Test func daysAreStartsOfDay() throws {
        let ny = calendar("America/New_York")
        let days = PlanDate.days(ofWeekContaining: try day("2026-03-10", ny), calendar: ny)  // spans US DST start
        #expect(days.count == 7)
        #expect(days.allSatisfy { ny.startOfDay(for: $0) == $0 })
    }

    @Test func shiftingByWeeks() throws {
        let utc = calendar("UTC")
        let start = try day("2026-10-05", utc)
        #expect(PlanDate.key(for: PlanDate.shifted(start, byWeeks: 1, calendar: utc), calendar: utc) == "2026-10-12")
        #expect(PlanDate.key(for: PlanDate.shifted(start, byWeeks: -1, calendar: utc), calendar: utc) == "2026-09-28")
        #expect(PlanDate.key(for: PlanDate.shifted(start, byWeeks: 0, calendar: utc), calendar: utc) == "2026-10-05")
    }

    @Test func theDefaultCalendarStartsWeeksOnMonday() {
        #expect(PlanDate.calendar.firstWeekday == 2)
        let keys = PlanDate.keys(ofWeekContaining: Date())
        #expect(keys.count == 7)
        let monday = PlanDate.date(forKey: keys[0]) ?? Date()
        #expect(PlanDate.calendar.component(.weekday, from: monday) == 2)
    }
}

@Suite("Meal plan mapping")
struct MealPlanMappingTests {
    private func meal(_ id: String, _ slot: MealSlot, servings: Int? = nil) -> PlannedMeal {
        PlannedMeal(id: id, recipeId: "r-\(id)", recipeName: "Recipe \(id)", slot: slot, servings: servings)
    }

    @Test func mealsRoundTrip() throws {
        let original = [meal("a", .dinner, servings: 4), meal("b", .breakfast)]
        let parsed = try #require(FirestoreMapping.meals(from: ["Meals": FirestoreMapping.mealFields(original)]))
        #expect(parsed.map(\.id) == ["b", "a"])  // breakfast before dinner
        #expect(parsed[1] == meal("a", .dinner, servings: 4))
        #expect(parsed[0].servings == nil)
    }

    @Test func mealsInTheSameSlotKeepTheirOrder() throws {
        let original = [meal("z", .lunch), meal("a", .lunch), meal("m", .lunch)]
        let parsed = try #require(FirestoreMapping.meals(from: ["Meals": FirestoreMapping.mealFields(original)]))
        #expect(parsed.map(\.id) == ["z", "a", "m"])
    }

    @Test func malformedMealsAreSkippedAndAMissingListIsNil() throws {
        let good: [String: Any] = ["Id": "g", "RecipeId": "r", "RecipeName": "Soup", "Slot": "lunch"]
        let data: [String: Any] = [
            "Meals": [
                good, ["Id": "", "RecipeId": "r", "RecipeName": "x", "Slot": "lunch"],
                ["Id": "n", "RecipeId": "r", "RecipeName": "x", "Slot": "brunch"],
                ["Id": "m", "RecipeName": "x", "Slot": "lunch"],
            ]
        ]
        #expect(try #require(FirestoreMapping.meals(from: data)).map(\.id) == ["g"])
        #expect(FirestoreMapping.meals(from: [:]) == nil)
        #expect(FirestoreMapping.meals(from: ["Meals": "lunch"]) == nil)
        #expect(try #require(FirestoreMapping.meals(from: ["Meals": [[String: Any]]()])).isEmpty)
    }

    @Test func slotsAreOrderedBreakfastToSnack() {
        #expect(MealSlot.allCases.sorted() == [.breakfast, .lunch, .dinner, .snack])
        #expect(MealSlot.allCases.allSatisfy { !$0.title.isEmpty && $0.id == $0.rawValue })
        #expect(MealSlot.allCases.map(\.rawValue) == ["breakfast", "lunch", "dinner", "snack"])
    }
}
