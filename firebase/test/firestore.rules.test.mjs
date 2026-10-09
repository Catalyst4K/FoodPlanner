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
  query,
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
      });
      await setDoc(doc(db, `Users/${ALICE}/Recipes/${id}/Ingredients/i0`), {
        Ref: ing(db), Order: 0, Quantity: 100, Unit: "g",
      });
    }
    await setDoc(doc(db, `Users/${ALICE}/Pantry/p1`), { Ingredient: ing(db) });
    await setDoc(doc(db, `Users/${ALICE}/ShoppingList/s1`), { Ingredient: ing(db) });
    // A recipe from before OwnerId existed.
    await setDoc(doc(db, `Users/${ALICE}/Recipes/legacy`), { Name: "Old", Instructions: "x" });
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

describe("recipes", () => {
  const recipe = (db, id) => doc(db, `Users/${ALICE}/Recipes/${id}`);
  it("owner can read, create, update, delete", async () => {
    const db = as(ALICE);
    await assertSucceeds(getDoc(recipe(db, "private")));
    await assertSucceeds(
      setDoc(recipe(db, "new"), { Name: "New", Instructions: "Cook", OwnerId: ALICE, IsShared: false }),
    );
    await assertSucceeds(updateDoc(recipe(db, "new"), { Name: "Renamed" }));
    await assertSucceeds(updateDoc(recipe(db, "new"), { IsShared: true }));
    await assertSucceeds(deleteDoc(recipe(db, "new")));
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
    await assertFails(setDoc(recipe(db, "mine"), { Name: "x", Instructions: "y", OwnerId: BOB }));
  });
  it("cannot claim another user as OwnerId", async () => {
    const db = as(ALICE);
    await assertFails(setDoc(recipe(db, "spoof"), { Name: "x", Instructions: "y", OwnerId: BOB }));
  });
  it("enforces field types and size limits", async () => {
    const db = as(ALICE);
    await assertFails(setDoc(recipe(db, "t1"), { Name: 5, Instructions: "y", OwnerId: ALICE }));
    await assertFails(setDoc(recipe(db, "t2"), { Name: "x", Instructions: "y".repeat(20001), OwnerId: ALICE }));
    await assertFails(setDoc(recipe(db, "t3"), { Name: "x".repeat(201), Instructions: "y", OwnerId: ALICE }));
    await assertFails(setDoc(recipe(db, "t4"), { Name: "x", Instructions: "y", OwnerId: ALICE, IsShared: "yes" }));
  });
  it("owner can still edit a legacy recipe that has no OwnerId", async () => {
    await assertSucceeds(updateDoc(recipe(as(ALICE), "legacy"), { Name: "Updated" }));
  });
  it("shared recipes are discoverable by collection-group query; unconstrained queries are not", async () => {
    const db = as(BOB);
    const shared = await assertSucceeds(
      getDocs(query(collectionGroup(db, "Recipes"), where("IsShared", "==", true))),
    );
    // One shared recipe, and nothing private leaks.
    assertEqual(shared.size, 1);
    await assertFails(getDocs(collectionGroup(db, "Recipes")));
  });
});

describe("recipe ingredient entries", () => {
  const entry = (db, recipe) => doc(db, `Users/${ALICE}/Recipes/${recipe}/Ingredients/i0`);
  it("owner can read and write them", async () => {
    const db = as(ALICE);
    await assertSucceeds(getDoc(entry(db, "private")));
    await assertSucceeds(setDoc(doc(db, `Users/${ALICE}/Recipes/private/Ingredients/i1`),
      { Ref: ing(db), Order: 1 }));
    await assertSucceeds(deleteDoc(entry(db, "private")));
  });
  it("others can read entries of a shared recipe only", async () => {
    const db = as(BOB);
    await assertSucceeds(getDoc(entry(db, "shared")));
    await assertSucceeds(getDocs(collection(db, `Users/${ALICE}/Recipes/shared/Ingredients`)));
    await assertFails(getDoc(entry(db, "private")));
    await assertFails(getDocs(collection(db, `Users/${ALICE}/Recipes/private/Ingredients`)));
  });
  it("others cannot write them", async () => {
    await assertFails(updateDoc(entry(as(BOB), "shared"), { Quantity: 999 }));
  });
  it("cannot be listed across all users", async () => {
    await assertFails(getDocs(collectionGroup(as(BOB), "Ingredients")));
    await assertFails(getDocs(collectionGroup(as(ALICE), "Ingredients")));
  });
  it("validates field types", async () => {
    const db = as(ALICE);
    const p = (id) => doc(db, `Users/${ALICE}/Recipes/private/Ingredients/${id}`);
    await assertFails(setDoc(p("a"), { Ref: "not-a-ref", Order: 0 }));
    await assertFails(setDoc(p("b"), { Ref: ing(db), Order: "first" }));
    await assertFails(setDoc(p("c"), { Ref: ing(db), Order: 0, Quantity: "lots" }));
    await assertFails(setDoc(p("d"), { Ref: ing(db), Order: 0, Unit: "u".repeat(41) }));
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
