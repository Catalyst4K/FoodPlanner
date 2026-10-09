// Seeds the local Firebase emulators with a demo account and made-up data, using
// the emulators' REST APIs (no Firebase account or admin SDK needed).
// Emulator-only: the project ID `demo-foodplanner` can never reach production.
// Data follows the current (v1) Firestore schema; update it when the schema changes.
//
//   make emulators-exec CMD="node seed.mjs"   (or run while `npm run emulators` is up)

const PROJECT = "demo-foodplanner";
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const FS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const DOC_PREFIX = `projects/${PROJECT}/databases/(default)/documents`;

export const DEMO_EMAIL = "demo@example.com";
export const DEMO_PASSWORD = "demo-password-123";

const ingredients = {
  spaghetti: "Spaghetti",
  tomatoes: "Tomatoes",
  garlic: "Garlic",
  oliveoil: "Olive oil",
  basil: "Basil",
  parmesan: "Parmesan",
  eggs: "Eggs",
  flour: "Flour",
  milk: "Milk",
  butter: "Butter",
  chicken: "Chicken breast",
  rice: "Rice",
  pepper: "Bell pepper",
  onion: "Onion",
};

const recipes = [
  {
    id: "recipe-spaghetti",
    name: "Tomato Basil Spaghetti",
    shared: true,
    created: "2026-09-01T10:00:00Z",
    instructions:
      "Boil the spaghetti. Fry the garlic in olive oil, add the tomatoes and simmer for 10 minutes. Toss with the pasta, torn basil and grated parmesan.",
    items: [
      ["spaghetti", 200, "g"],
      ["tomatoes", 400, "g"],
      ["garlic", 2, "cloves"],
      ["oliveoil", 2, "tbsp"],
      ["basil", 1, "bunch"],
      ["parmesan", 30, "g"],
    ],
  },
  {
    id: "recipe-pancakes",
    name: "Fluffy Pancakes",
    shared: false,
    created: "2026-09-02T10:00:00Z",
    instructions:
      "Whisk the flour, milk and eggs into a smooth batter. Melt a little butter in a pan and cook ladlefuls for 2 minutes per side.",
    items: [
      ["flour", 150, "g"],
      ["milk", 200, "ml"],
      ["eggs", 2, null],
      ["butter", 20, "g"],
    ],
  },
  {
    id: "recipe-stirfry",
    name: "Chicken Stir-fry",
    shared: false,
    created: "2026-09-03T10:00:00Z",
    instructions:
      "Slice the chicken, pepper and onion. Stir-fry the chicken until golden, add the vegetables for 4 minutes, and serve over rice.",
    items: [
      ["chicken", 300, "g"],
      ["pepper", 2, null],
      ["onion", 1, null],
      ["rice", 150, "g"],
    ],
  },
];

const pantry = ["spaghetti", "garlic", "oliveoil", "eggs", "flour", "rice"];
const shopping = ["tomatoes", "basil", "milk"];

const str = (stringValue) => ({ stringValue });
const ts = (timestampValue) => ({ timestampValue });
const ref = (key) => ({ referenceValue: `${DOC_PREFIX}/Ingredients/ing-${key}` });

async function json(url, init) {
  const res = await fetch(url, init);
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, body };
}

async function ensureUser() {
  const payload = JSON.stringify({ email: DEMO_EMAIL, password: DEMO_PASSWORD, returnSecureToken: true });
  const headers = { "Content-Type": "application/json" };
  let r = await json(`${AUTH}/accounts:signUp?key=fake`, { method: "POST", headers, body: payload });
  if (!r.ok) {
    r = await json(`${AUTH}/accounts:signInWithPassword?key=fake`, { method: "POST", headers, body: payload });
  }
  if (!r.ok) throw new Error(`Could not create or sign in demo user: ${JSON.stringify(r.body)}`);
  return r.body.localId;
}

async function put(path, fields) {
  const r = await json(`${FS}/${path}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Authorization: "Bearer owner" },
    body: JSON.stringify({ fields }),
  });
  if (!r.ok) throw new Error(`Write ${path} failed: ${JSON.stringify(r.body)}`);
}

const uid = await ensureUser();
const user = `Users/${uid}`;

for (const [key, name] of Object.entries(ingredients)) {
  await put(`Ingredients/ing-${key}`, { Name: str(name), NameLower: str(name.toLowerCase()) });
}

for (const recipe of recipes) {
  const path = `${user}/Recipes/${recipe.id}`;
  await put(path, {
    Name: str(recipe.name),
    Instructions: str(recipe.instructions),
    OwnerId: str(uid),
    IsShared: { booleanValue: recipe.shared },
    CreatedAt: ts(recipe.created),
  });
  for (const [index, [key, quantity, unit]] of recipe.items.entries()) {
    const fields = { Ref: ref(key), Order: { integerValue: String(index) }, Quantity: { doubleValue: quantity } };
    if (unit) fields.Unit = str(unit);
    await put(`${path}/Ingredients/item-${index}`, fields);
  }
}

for (const [index, key] of pantry.entries()) {
  await put(`${user}/Pantry/pantry-${key}`, { Ingredient: ref(key), CreatedAt: ts(`2026-09-10T10:0${index}:00Z`) });
}
for (const [index, key] of shopping.entries()) {
  await put(`${user}/ShoppingList/shop-${key}`, { Ingredient: ref(key), CreatedAt: ts(`2026-09-11T10:0${index}:00Z`) });
}

console.log(`Seeded demo account ${DEMO_EMAIL} (${uid}): ${recipes.length} recipes, ${pantry.length} pantry, ${shopping.length} shopping items`);
