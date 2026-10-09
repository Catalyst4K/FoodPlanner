# Full Liquid Glass icon — plan

## Where we are

The app icon currently shipped ([AppIcon.appiconset](../FoodPlanner/Assets.xcassets/AppIcon.appiconset), [AppIcon-Basil.appiconset](../FoodPlanner/Assets.xcassets/AppIcon-Basil.appiconset)) is the Satchel mark as **flattened, static PNGs** — one 1024×1024 bitmap per appearance (Light/Dark/Tinted), with the glass highlight, specular streak, and badge shadow all baked into the pixels by hand in an SVG render harness.

That's a good approximation, but it's not real Liquid Glass. The system never dynamically blurs, refracts, or parallaxes anything in it — it's a picture of glass, not glass. Genuine Liquid Glass icons are authored as **layered `.icon` files** in Apple's Icon Composer (ships with Xcode 26), which the system renders live: real-time blur against the actual wallpaper behind the icon, specular highlights that respond to device tilt, per-layer parallax, and correct behavior in Tinted/Clear appearances without us pre-baking anything.

This doc is the plan for closing that gap.

## Why this needs a human at a GUI

Icon Composer is a native macOS app with no CLI, no scripting interface, and no file format I can safely hand-author blind — it's not exposed to Claude Code's tools, and there's no MCP surface for it. Everything up through "prepare clean layer assets" I can do unattended; authoring the actual `.icon` file has to happen interactively in the app.

## Phase 1 — Prepare layer assets (I can do this)

Icon Composer wants separate, alpha-transparent PNGs per layer — no baked shadows, no baked highlight blobs, no baked specular streak (the system adds all of that live). That means re-deriving simpler assets from the SVG glyph markup used to build the current flattened icons (it lived in a session-local scratchpad file, `icon-render.html`, which won't persist between sessions — the glyph coordinates are also reproduced in full in the [logo concepts artifact](https://claude.ai/code/artifact/ff01f6a6-5857-4783-88df-317716aa9bd8), so nothing is actually lost):

- [ ] **Background layer** — flat two-stop gradient only (persimmon / basil), full-bleed 1024×1024, opaque. Drop the highlight blob and specular streak; Icon Composer's glass material replaces them.
- [ ] **Bag layer** — the satchel body + handle silhouette, white, alpha PNG, transparent everywhere else. This is the one that should sit "lowest" (closest to background).
- [ ] **List-lines layer** — the three checklist bars. Candidate to merge into the bag layer (they're the same visual plane) or keep separate if we want a subtle parallax split.
- [ ] **Badge layer** — the white circle behind the utensil mark, alpha PNG, no baked drop shadow (Icon Composer's own layer elevation should cast one). This is the layer that benefits most from real parallax — it should float slightly proud of the bag.
- [ ] **Badge glyph layer** (or merged into badge layer) — the fork/knife engraving.

Each layer at 1024×1024, generous transparent padding matching what we already tuned (content ~82% of frame), one set for Persimmon, one for Basil.

## Phase 2 — Author the `.icon` file (needs Xcode 26 + Icon Composer, interactive)

1. Open Icon Composer (Xcode → Open Developer Tool → Icon Composer, or launch standalone if installed separately).
2. New icon document. Import the background layer.
3. Add the bag, badge, and glyph layers as separate groups in the canvas; set relative z-order/elevation so the badge reads as physically above the bag.
4. Assign each foreground layer's material (glass/blur amount) and check how the system-generated specular and blur look against the layer stack — this replaces everything we hand-painted in Phase 1's discarded highlight/specular.
5. Configure the four appearances (Light, Dark, Tinted, Clear):
   - Light/Dark likely just need the background gradient swapped (reuse the persimmon-dark / basil-dark stops we already have).
   - Tinted/Clear should fall out mostly for free if the foreground layers are clean single-alpha shapes (which was the whole point of the badge's real transparent gap in the current flat version — carry that same discipline into the layer PNGs).
6. Preview: Icon Composer has a live preview including simulated device tilt — check the badge's parallax doesn't separate it so far from the bag that the "pinned like a price tag" reading breaks.
7. Repeat for the Basil colourway (either as a second `.icon` file, or as a second background configuration inside one file if Icon Composer supports multiple named variants — needs checking once we're in the tool).
8. Export / save the `.icon` package into the repo, e.g. `FoodPlanner/Assets.xcassets/AppIcon.icon` (exact placement to confirm once we see how Icon Composer wants to integrate with an existing `PBXFileSystemSynchronizedRootGroup`-based project).

## Phase 3 — Wire into the Xcode project

- `.icon` replaces the current appiconset as the thing `ASSETCATALOG_COMPILER_APPICON_NAME` points at (name should stay `AppIcon` so nothing else needs to change).
- Since `IPHONEOS_DEPLOYMENT_TARGET = 26.0` already (see [CLAUDE.md](../CLAUDE.md)), there's no pre-26 fallback to worry about — no need to keep the flattened appiconset around for older OS support once this lands. Until then, don't delete it; it's the working fallback.
- For the Basil alternate icon: confirm whether Xcode 26's `CFBundleAlternateIcons` mechanism accepts an `.icon` file the same way it currently accepts an appiconset name ([Info.plist](../Supporting/Info.plist)) — this is the biggest unknown in the whole plan and needs a real test, not an assumption.
- Rebuild with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ... build` (same as this session used, since `xcode-select` here still points at Command Line Tools) and confirm **BUILD SUCCEEDED** before touching anything else.

## Phase 4 — Verify

- Simulator: confirm it still builds and shows *something* correct (simulators can't show tilt parallax — no gyroscope — but should show the live blur/specular).
- Real device (if available): the actual point of this whole exercise — check the parallax-on-tilt and live wallpaper blur, which is impossible to verify any other way.
- Re-check all four appearances (Light/Dark/Tinted/Clear) on-device, plus the Basil alternate icon switch.

## Rollback

Everything from the current static-PNG version stays in git history and in the working tree until Phase 3 actually replaces it — this is additive work, not a rewrite in place. If Icon Composer's alternate-icon story doesn't pan out (Phase 3's flagged unknown), we keep shipping the flattened Basil appiconset as-is and only upgrade the primary icon.

## Open questions to resolve once inside Icon Composer

- Does one `.icon` file support multiple named colourways, or do we need two separate `.icon` files (Persimmon, Basil)?
- Exact recommended layer count / whether Apple's guidance discourages more than ~3 foreground layers for performance or clarity.
- Whether `CFBundleAlternateIcons` can reference a `.icon` package by name the same way it references an appiconset.
