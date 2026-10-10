import SwiftUI

/// The weekly meal plan: one section per day, meals listed by slot.
struct PlanView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var pickerDay: PickerDay?
    @State private var showingShoppingSheet = false

    private struct PickerDay: Identifiable {
        let date: Date
        var id: String { PlanDate.key(for: date) }
    }

    private struct PlanRoute: Hashable { let recipeId: String }

    private var days: [Date] { PlanDate.days(ofWeekContaining: dataManager.planWeekStart) }
    private var todayKey: String { PlanDate.key(for: Date()) }
    private var isCurrentWeek: Bool { dataManager.planWeekStart == PlanDate.startOfWeek(containing: Date()) }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(days, id: \.self) { day in
                    daySection(day).id(PlanDate.key(for: day))
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .safeAreaInset(edge: .top, spacing: 0) { weekHeader }
            .onAppear { scrollToToday(proxy) }
            .onChange(of: dataManager.planWeekStart) { _, _ in scrollToToday(proxy) }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingShoppingSheet = true
                } label: {
                    Image(systemName: "cart.badge.plus")
                }
                .accessibilityLabel("Add missing ingredients to shopping list")
                .accessibilityIdentifier("plan.shopping")
            }
        }
        .navigationDestination(for: PlanRoute.self) { route in
            if let recipe = recipe(withID: route.recipeId) {
                RecipeDetailView(recipe: recipe)
            } else {
                ContentUnavailableView("Recipe not found", systemImage: "questionmark.folder")
            }
        }
        .sheet(item: $pickerDay) { day in
            PlanRecipePicker(date: day.date)
        }
        .sheet(isPresented: $showingShoppingSheet) {
            PlanShoppingSheet()
        }
    }

    // MARK: - Week header

    private var weekHeader: some View {
        HStack(spacing: 12) {
            weekButton("chevron.left", label: "Previous week", id: "plan.previous", weeks: -1)
            VStack(spacing: 2) {
                Text(
                    isCurrentWeek
                        ? "This week"
                        : "Week of " + dataManager.planWeekStart.formatted(.dateTime.day().month(.abbreviated))
                )
                .font(.title3.weight(.semibold))
                Text(weekRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("plan.weekTitle")
            weekButton("chevron.right", label: "Next week", id: "plan.next", weeks: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if !isCurrentWeek {
                Button("Today") { dataManager.showPlanWeek(containing: Date()) }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .offset(y: 28)
                    .accessibilityIdentifier("plan.today")
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, isCurrentWeek ? 8 : 36)
        .background(Color(.systemGroupedBackground))
    }

    private func weekButton(_ symbol: String, label: String, id: String, weeks: Int) -> some View {
        Button {
            dataManager.showPlanWeek(containing: PlanDate.shifted(dataManager.planWeekStart, byWeeks: weeks))
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private var weekRange: String {
        guard let first = days.first, let last = days.last else { return "" }
        let sameMonth = PlanDate.calendar.isDate(first, equalTo: last, toGranularity: .month)
        let start = first.formatted(sameMonth ? .dateTime.day() : .dateTime.day().month(.abbreviated))
        return start + " – " + last.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Days

    private func daySection(_ day: Date) -> some View {
        let key = PlanDate.key(for: day)
        let meals = dataManager.mealPlan[key] ?? []
        return Section {
            if meals.isEmpty {
                Button {
                    pickerDay = PickerDay(date: day)
                } label: {
                    Text("Nothing planned")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))
                .accessibilityIdentifier("plan.empty.\(key)")
            }
            ForEach(meals) { meal in
                mealRow(meal, on: day)
            }
        } header: {
            dayHeader(day, key: key, hasMeals: !meals.isEmpty)
        }
    }

    private func dayHeader(_ day: Date, key: String, hasMeals: Bool) -> some View {
        let isToday = key == todayKey
        return HStack(spacing: 8) {
            Text(day.formatted(.dateTime.weekday(.wide)))
                .font(.headline)
                .foregroundStyle(isToday ? Color.accentColor : .primary)
            Text(day.formatted(.dateTime.day().month(.abbreviated)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isToday {
                Text("Today")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                pickerDay = PickerDay(date: day)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel("Add meal on \(day.formatted(.dateTime.weekday(.wide)))")
            .accessibilityIdentifier("plan.add.\(key)")
        }
        .textCase(nil)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.day.\(key)")
    }

    private func mealRow(_ meal: PlannedMeal, on day: Date) -> some View {
        NavigationLink(value: PlanRoute(recipeId: meal.recipeId)) {
            HStack(spacing: 12) {
                Image(systemName: meal.slot.symbol)
                    .font(.body)
                    .foregroundStyle(meal.slot.tint)
                    .frame(width: 34, height: 34)
                    .background(meal.slot.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.recipeName)
                    Text(meal.slot.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                Task { await dataManager.removeMeal(meal, on: day) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .accessibilityIdentifier("plan.remove.\(meal.id)")
        }
        .accessibilityIdentifier("plan.meal.\(meal.recipeName)")
    }

    // MARK: - Helpers

    private func recipe(withID id: String) -> Recipe? {
        dataManager.userRecipes.first { $0.id == id } ?? dataManager.sharedRecipes.first { $0.id == id }
    }

    /// Opens the current week at today rather than at Monday, so the days that matter are on screen.
    private func scrollToToday(_ proxy: ScrollViewProxy) {
        guard isCurrentWeek else { return }
        Task { proxy.scrollTo(todayKey, anchor: .top) }
    }
}

/// Choose a recipe (and slot) to plan on a given day.
struct PlanRecipePicker: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var slot: MealSlot = .dinner
    @State private var searchText = ""

    private var recipes: [Recipe] {
        let matching = RecipeSearch.filter(dataManager.userRecipes, query: searchText)
        return RecipeSort.sorted(matching, by: .pantryMatch, pantry: dataManager.pantryIngredients)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("plan.picker.slot")
                }
                if recipes.isEmpty {
                    Text(searchText.isEmpty ? "Add a recipe first." : "No recipes match “\(searchText)”.")
                        .foregroundStyle(.secondary)
                }
                ForEach(recipes) { recipe in
                    Button {
                        Task {
                            if await dataManager.addMeal(recipe: recipe, on: date, slot: slot) { dismiss() }
                        }
                    } label: {
                        HStack {
                            Text(recipe.title).foregroundStyle(.primary)
                            Spacer()
                            Text("\(dataManager.matchedIngredientCount(for: recipe))/\(recipe.ingredients.count)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("plan.pick.\(recipe.title)")
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("plan.picker.cancel")
                }
            }
        }
    }
}

/// "Add to plan" from a recipe: pick the day and slot.
struct AddToPlanSheet: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var date = Date()
    @State private var slot: MealSlot = .dinner

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $date, displayedComponents: .date)
                    .accessibilityIdentifier("addToPlan.date")
                Picker("Meal", selection: $slot) {
                    ForEach(MealSlot.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("addToPlan.slot")
            }
            .navigationTitle("Add to plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("addToPlan.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            if await dataManager.addMeal(recipe: recipe, on: date, slot: slot) { dismiss() }
                        }
                    }
                    .accessibilityIdentifier("addToPlan.add")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Confirms what the week's plan will add to the shopping list.
struct PlanShoppingSheet: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var unchecked: Set<String> = []

    private var items: [IngredientItem] { dataManager.missingIngredientsForPlan }
    private var chosen: [IngredientItem] { items.filter { !unchecked.contains($0.id) } }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing to buy", systemImage: "checkmark.circle",
                        description: Text("Everything this week's plan needs is in your pantry or on your list.")
                    )
                    .accessibilityIdentifier("planShopping.empty")
                }
                ForEach(items) { item in
                    Button {
                        if unchecked.contains(item.id) { unchecked.remove(item.id) } else { unchecked.insert(item.id) }
                    } label: {
                        HStack {
                            Image(systemName: unchecked.contains(item.id) ? "circle" : "checkmark.circle.fill")
                            Text(IngredientFormatter.format(quantity: item.quantity, unit: item.unit, name: item.name))
                                .foregroundStyle(.primary)
                        }
                    }
                    .accessibilityIdentifier("planShopping.item.\(item.name)")
                }
            }
            .navigationTitle("Add to shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("planShopping.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(chosen.count)") {
                        Task {
                            if await dataManager.addToShoppingList(items: chosen) { dismiss() }
                        }
                    }
                    .disabled(chosen.isEmpty)
                    .accessibilityIdentifier("planShopping.add")
                }
            }
        }
    }
}

extension MealSlot {
    /// SF Symbol for the slot's icon chip.
    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast: .orange
        case .lunch: .yellow
        case .dinner: .indigo
        case .snack: .green
        }
    }
}
