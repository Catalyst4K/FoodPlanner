// Allow and deny tests for firestore.rules. Run with `npm run test:emulated`.
// Everything uses the demo-foodplanner emulator project; nothing touches production.
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

let env;
const ALICE = "alice";
const BOB = "bob";

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const ing = (db, id = "ing-flour") => doc(db, `Ingredients/${id}`);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-foodplanner",
    firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Seed with rules disabled: alice has a private and a shared recipe, each with one ingredient.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(ing(db), { Name: "Flour", NameLower: "flour" });
    for (const [id, shared] of [["private", false], ["shared", true]]) {
      await setDoc(doc(db, `Users/${ALICE}/Recipes/${id}`), {
        Name: id, Instructions: "Mix.", OwnerId: ALICE, IsShared: shared,
        Ingredients: [{ Name: "Flour", Quantity: 100, Unit: "g" }],
      });
    }
    await setDoc(doc(db, `Users/${ALICE}/Pantry/p1`), { Ingredient: ing(db) });
    await setDoc(doc(db, `Users/${ALICE}/ShoppingList/s1`), { Ingredient: ing(db) });
  });
});

describe("unauthenticated users", () => {
  it("cannot read or write anything", async () => {
    const db = anon();
    await assertFails(getDoc(ing(db)));
    await assertFails(getDoc(doc(db, `Users/${ALICE}/Recipes/shared`)));
    await assertFails(getDoc(doc(db, `Users/${ALICE}/Recipes/shared/Ingredients/i0`)));
    await assertFails(getDoc(doc(db, `Users/${ALICE}/Pantry/p1`)));
    await assertFails(setDoc(doc(db, `Users/${ALICE}/Pantry/p2`), { Ingredient: ing(db) }));
    await assertFails(getDocs(query(collectionGroup(db, "Recipes"), where("IsShared", "==", true))));
  });
});

describe("global Ingredients", () => {
  it("signed-in users can read and create a valid entry", async () => {
    const db = as(BOB);
    await assertSucceeds(getDoc(ing(db)));
    await assertSucceeds(setDoc(ing(db, "ing-rice"), { Name: "Rice", NameLower: "rice" }));
  });
  it("accepts accented names (the app lowercases with Swift, not with the rules language)", async () => {
    await assertSucceeds(setDoc(ing(as(BOB), "ing-eclair"), { Name: "Éclair", NameLower: "éclair" }));
  });
  it("rejects extra fields, empty and oversized names", async () => {
    const db = as(BOB);
    await assertFails(setDoc(ing(db, "a"), { Name: "Rice", NameLower: "rice", Evil: "x" }));
    await assertFails(setDoc(ing(db, "c"), { Name: "", NameLower: "" }));
    const long = "x".repeat(81);
    await assertFails(setDoc(ing(db, "d"), { Name: long, NameLower: long }));
  });
  it("entries are immutable", async () => {
    const db = as(BOB);
    await assertFails(updateDoc(ing(db), { Name: "Hacked" }));
    await assertFails(deleteDoc(ing(db)));
  });
});

describe("recipes (schema v2)", () => {
  const recipe = (db, id) => doc(db, `Users/${ALICE}/Recipes/${id}`);
  const valid = (extra = {}) => ({
    Name: "New", Instructions: "Cook", OwnerId: ALICE, IsShared: false,
    Ingredients: [{ Name: "Rice", Quantity: 1.5, Unit: "cup" }, { Name: "Salt" }], ...extra,
  });
  it("owner can read, create, update, delete", async () => {
    const db = as(ALICE);
    await assertSucceeds(getDoc(recipe(db, "private")));
    await assertSucceeds(setDoc(recipe(db, "new"), valid()));
    await assertSucceeds(updateDoc(recipe(db, "new"), { Name: "Renamed" }));
    await assertSucceeds(updateDoc(recipe(db, "new"), { IsShared: true }));
    await assertSucceeds(updateDoc(recipe(db, "new"), { Ingredients: [{ Name: "Oats" }] }));
    await assertSucceeds(deleteDoc(recipe(db, "new")));
  });
  it("accepts exactly the payloads DataManager sends (server timestamps included)", async () => {
    const db = as(ALICE);
    const ref = recipe(db, "from-app");
    // addRecipe: FirestoreMapping.recipeFields + OwnerId, IsShared, CreatedAt, UpdatedAt
    await assertSucceeds(
      setDoc(ref, {
        Name: "Pancakes", Instructions: "Mix.", Ingredients: [{ Name: "Flour", Quantity: 150, Unit: "g" }, { Name: "Eggs", Quantity: 2 }],
        OwnerId: ALICE, IsShared: false, CreatedAt: serverTimestamp(), UpdatedAt: serverTimestamp(),
      }),
    );
    // updateRecipe: recipeFields + UpdatedAt
    await assertSucceeds(
      updateDoc(ref, {
        Name: "Better pancakes", Instructions: "Whisk.", Ingredients: [{ Name: "Flour" }], UpdatedAt: serverTimestamp(),
      }),
    );
    // setShared
    await assertSucceeds(updateDoc(ref, { IsShared: true }));
    // saveSharedRecipeToMyList: addRecipe with SourceRecipePath
    await assertSucceeds(
      setDoc(recipe(db, "copy"), {
        Name: "Copy", Instructions: "", Ingredients: [], OwnerId: ALICE, IsShared: false,
        SourceRecipePath: `Users/${BOB}/Recipes/abc123`, CreatedAt: serverTimestamp(), UpdatedAt: serverTimestamp(),
      }),
    );
  });
  it("accepts optional fields: servings, source path, timestamps", async () => {
    const db = as(ALICE);
    await assertSucceeds(
      setDoc(recipe(db, "full"), valid({ Servings: 4, SourceRecipePath: `Users/${BOB}/Recipes/x` })),
    );
  });
  it("other users can read a shared recipe but not a private one", async () => {
    const db = as(BOB);
    await assertSucceeds(getDoc(recipe(db, "shared")));
    await assertFails(getDoc(recipe(db, "private")));
  });
  it("other users cannot write or delete", async () => {
    const db = as(BOB);
    await assertFails(updateDoc(recipe(db, "shared"), { Name: "Hacked" }));
    await assertFails(deleteDoc(recipe(db, "shared")));
    await assertFails(setDoc(recipe(db, "mine"), valid({ OwnerId: BOB })));
  });
  it("OwnerId must be the writer and can't change", async () => {
    const db = as(ALICE);
    await assertFails(setDoc(recipe(db, "spoof"), valid({ OwnerId: BOB })));
    const { OwnerId, ...noOwner } = valid();
    await assertFails(setDoc(recipe(db, "anon"), noOwner));
    await assertFails(updateDoc(recipe(db, "private"), { OwnerId: BOB }));
  });
  it("requires an Ingredients array of at most 100 entries", async () => {
    const db = as(ALICE);
    const { Ingredients, ...none } = valid();
    await assertFails(setDoc(recipe(db, "n1"), none));
    await assertFails(setDoc(recipe(db, "n2"), valid({ Ingredients: "flour" })));
    await assertFails(setDoc(recipe(db, "n3"), valid({ Ingredients: Array(101).fill({ Name: "x" }) })));
    await assertSucceeds(setDoc(recipe(db, "n4"), valid({ Ingredients: Array(100).fill({ Name: "x" }) })));
  });
  it("rejects unknown fields", async () => {
    await assertFails(setDoc(recipe(as(ALICE), "extra"), valid({ Evil: "x" })));
  });
  it("enforces field types and size limits", async () => {
    const db = as(ALICE);
    await assertFails(setDoc(recipe(db, "t1"), valid({ Name: 5 })));
    await assertFails(setDoc(recipe(db, "t2"), valid({ Instructions: "y".repeat(20001) })));
    await assertFails(setDoc(recipe(db, "t3"), valid({ Name: "x".repeat(201) })));
    await assertFails(setDoc(recipe(db, "t4"), valid({ IsShared: "yes" })));
    await assertFails(setDoc(recipe(db, "t5"), valid({ Servings: 0 })));
    await assertFails(setDoc(recipe(db, "t6"), valid({ Servings: 2.5 })));
    await assertFails(setDoc(recipe(db, "t7"), valid({ SourceRecipePath: "p".repeat(201) })));
  });
  it("shared recipes are discoverable by collection-group query; unconstrained queries are not", async () => {
    const db = as(BOB);
    const shared = await assertSucceeds(
      getDocs(query(collectionGroup(db, "Recipes"), where("IsShared", "==", true))),
    );
    assertEqual(shared.size, 1);
    await assertFails(getDocs(collectionGroup(db, "Recipes")));
  });
  it("the app's shared query (ordered, limited) is allowed", async () => {
    const db = as(BOB);
    await assertSucceeds(
      getDocs(
        query(collectionGroup(db, "Recipes"), where("IsShared", "==", true), orderBy("CreatedAt", "desc"), limit(200)),
      ),
    );
  });
  it("the v1 per-recipe ingredient subcollection is no longer accessible to anyone", async () => {
    for (const uid of [ALICE, BOB]) {
      const db = as(uid);
      await assertFails(getDoc(doc(db, `Users/${ALICE}/Recipes/shared/Ingredients/i0`)));
      await assertFails(getDocs(collectionGroup(db, "Ingredients")));
    }
    await assertFails(
      setDoc(doc(as(ALICE), `Users/${ALICE}/Recipes/private/Ingredients/i1`), { Order: 1 }),
    );
  });
});

describe("pantry and shopping list", () => {
  for (const name of ["Pantry", "ShoppingList"]) {
    const path = (id) => `Users/${ALICE}/${name}/${id}`;
    const existing = name === "Pantry" ? "p1" : "s1";
    it(`${name}: owner has full access`, async () => {
      const db = as(ALICE);
      await assertSucceeds(getDoc(doc(db, path(existing))));
      await assertSucceeds(setDoc(doc(db, path("new")), { Ingredient: ing(db) }));
      await assertSucceeds(deleteDoc(doc(db, path("new"))));
    });
    it(`${name}: other users have no access`, async () => {
      const db = as(BOB);
      await assertFails(getDoc(doc(db, path(existing))));
      await assertFails(setDoc(doc(db, path("x")), { Ingredient: ing(db) }));
      await assertFails(deleteDoc(doc(db, path(existing))));
      await assertFails(getDocs(collection(db, `Users/${ALICE}/${name}`)));
    });
    it(`${name}: Ingredient must be a document reference`, async () => {
      await assertFails(setDoc(doc(as(ALICE), path("bad")), { Ingredient: "flour" }));
    });
  }
});

function assertEqual(actual, expected) {
  if (actual !== expected) throw new Error(`expected ${expected}, got ${actual}`);
}
