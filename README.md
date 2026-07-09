# deadweight — Shredder Empire (working title)

Incremental/tycoon game: start with a weak shredder, drag junk into it for
cash, upgrade power, and unlock bigger shredder tiers. Loosely inspired by
"satisfying shredder" videos.

## MVP scope (v0.1)

- **Platform:** Steam desktop first (Godot exports natively to
  Windows/Mac/Linux); mobile export considered for later without a rewrite.
- **Monetization:** paid-once, no ads/IAP in the MVP.
- **Core loop:** items spawn in a tray → player drags them into the
  shredder mouth → item is destroyed and converted to money → money buys
  upgrades (shredder power, then a full tier upgrade to a bigger machine).
- **Art:** placeholder geometric primitives in true 3D (`MeshInstance3D`
  boxes/planes, a procedurally-generated hopper mesh) viewed from an
  angled `Camera3D` — mechanics first, real art later.
- **Out of scope for v0.1** (tracked for the roadmap): auto-feed upgrade,
  multiple item/material types, prestige beyond the 5 tiers, Steam
  achievements/leaderboards, final art, mobile port.

## Engine

Godot 4.3+ (GL Compatibility renderer). Chosen over Unity because it has no
royalties/revenue-share, which matters for a paid-once Steam release, and it
handles simple 2D drag physics and Steam export cleanly.

## Project layout

```
project.godot
scenes/
  Main.tscn            # 3D scene: camera, light, ground, belt, hopper, HUD, shop
  ShreddableItem.tscn   # draggable junk placeholder (Area3D cube)
  Burst.tscn            # one-shot shred particle effect (CPUParticles3D)
scripts/
  Economy.gd            # autoload: money, power/tier levels, cost curves
  SaveManager.gd         # autoload: JSON save/load to user://savegame.json
  Main.gd                # wires HUD + spawner + shop to Economy, aims the camera
  ShreddableItem.gd       # conveyor ride + drag-and-drop behavior (3D raycast)
  ShredderMouth.gd        # detects items over the hopper, awards money, shreds
  HopperMesh.gd            # procedurally builds the funnel/hopper mesh
```

## Running locally

This project was authored without access to the Godot editor (not
available in this environment), so it hasn't been opened/run in-engine yet.
To try it:

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build).
2. Open this folder as a project (`project.godot`) in the editor.
3. Press F5 (or the Play button) to run `scenes/Main.tscn`.
4. Objects spawn at the top of the conveyor belt and slide down its
   center; drag a red cube (at any point along the belt) into the dark
   hopper at the bottom to earn money, then use the shop buttons
   (bottom-right) to buy upgrades.

Since the scenes were hand-written as text rather than saved from the
editor, double-check on first open for anything Godot wants to
auto-resolve (e.g. resource UIDs) — it should just work, but this hasn't
been verified in-engine.

## Tuning the economy

All balancing constants live in `scripts/Economy.gd`: item base value,
power upgrade cost/growth, tier upgrade cost/growth, and the per-tier
value multipliers/names. Change those to reshape the progression curve.
