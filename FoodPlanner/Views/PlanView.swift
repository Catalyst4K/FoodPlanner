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

    private var days: [Date] { PlanDate.days(ofWeekContaining: dataManager.planWeekStart) }

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(meals(on: day)) { meal in
                        mealRow(meal, on: day)
                    }
                    Button {
                        pickerDay = PickerDay(date: day)
                    } label: {
                        Label("Add meal", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("plan.add.\(PlanDate.key(for: day))")
                } header: {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .accessibilityIdentifier("plan.day.\(PlanDate.key(for: day))")
                }
            }
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
        .sheet(isPresented: $showingShoppingSheet) {
            PlanShoppingSheet()
        }
        .safeAreaInset(edge: .top) { weekHeader }
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
    }

    private struct PlanRoute: Hashable { let recipeId: String }

    private func meals(on day: Date) -> [PlannedMeal] {
        dataManager.mealPlan[PlanDate.key(for: day)] ?? []
    }

    private func recipe(withID id: String) -> Recipe? {
        dataManager.userRecipes.first { $0.id == id } ?? dataManager.sharedRecipes.first { $0.id == id }
    }

    private func mealRow(_ meal: PlannedMeal, on day: Date) -> some View {
        NavigationLink(value: PlanRoute(recipeId: meal.recipeId)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.slot.title).font(.caption).foregroundStyle(.secondary)
                Text(meal.recipeName)
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

    private var weekHeader: some View {
        HStack {
            Button {
                dataManager.showPlanWeek(containing: PlanDate.shifted(dataManager.planWeekStart, byWeeks: -1))
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous week")
            .accessibilityIdentifier("plan.previous")

            Spacer()
            Button(weekTitle) {
                dataManager.showPlanWeek(containing: Date())
            }
            .accessibilityIdentifier("plan.today")
            Spacer()

            Button {
                dataManager.showPlanWeek(containing: PlanDate.shifted(dataManager.planWeekStart, byWeeks: 1))
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next week")
            .accessibilityIdentifier("plan.next")
        }
        .padding()
        .background(.bar)
    }

    private var weekTitle: String {
        let start = dataManager.planWeekStart
        if start == PlanDate.startOfWeek(containing: Date()) { return "This week" }
        return "Week of " + start.formatted(.dateTime.day().month(.abbreviated))
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
