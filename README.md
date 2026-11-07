# Breakout Royale 3D

A portrait-first 3D brick-breaker built with **Godot 4.7** and exported to the
browser. 1,000 campaign levels across 20 worlds, 20 multi-phase bosses and 40
power-ups, with Little Joy Arcade accounts, cloud saves and trophies.

Live: <https://jd4rider.github.io/breakout-royale/>

## Play

- **Drag anywhere** to slide the paddle. Mouse movement, arrow keys and WASD
  work on desktop.
- **Tap / Space** launches the ball. Where it lands on the paddle sets the
  angle: centre is steep, edges are wide.
- Break every brick, or take down the boss core on boss levels.
- Catch capsules. The red-ringed ones are risky, not rewards.
- Stars come from score: par is two stars, 145% of par is three.

Modes: Campaign, Endless, Survival, Boss Rush, Daily Challenge, Zen Patrol and
Arcade Classic (classic rules, no power-ups).

## Architecture

```
Scenes/            Main scene and the headless test scene
Scripts/Main.gd    Menus, campaign map, HUD, results, settings
Scripts/Game/      GameField: authoritative paddle/ball/brick/boss simulation
Scripts/Core/      Campaign, PowerUps, BreakoutMath, SaveManager, ArcadeBridge, Audio
Assets/Models/     Blender-authored GLBs (paddle, bricks, ball, capsule, boss, arena)
Assets/Audio/      Synthesised WAV effects and two music beds
Blender/           Editable asset build script and .blend sources
Tools/             Web patch script, audio synthesis, browser smoke test
Tests/             Headless regression suite
Web/               Arcade bridge and the drop-in account client
```

The simulation lives on a 2D plane and never reads a mesh. `GameField` steps it
at a fixed **120 Hz** with swept circle-vs-box collisions, so a fast ball cannot
tunnel through a brick. Rendering adds the depth: an orthographic camera at a
slight angle, per-world palettes, a shader backdrop and 3D shards.

Every level is generated from a seed (`Campaign.generate(id)`) and validated in
CI: grid bounds, no duplicate cells, a breakable path, at least twelve bricks,
boss levels start empty, and a positive par score.

## Develop

```bash
# assets (optional: the GLBs are committed)
blender -b -P Blender/build_assets.py
python3 Tools/audio.py

# tests
godot --headless --path . Scenes/Tests.tscn

# export + web shell
godot --headless --path . --export-release "Web" web/play/index.html
python3 Tools/patch_web.py

# local smoke test
python3 -m http.server 4174 --directory web/play &
node Tools/smoke.mjs http://127.0.0.1:4174/
```

Pushing to `main` runs the same tests and exports to GitHub Pages
(`.github/workflows/pages.yml`).

## Saves and the arcade

`SaveManager` is local-first: a versioned JSON save in `user://`, written after
every board. `ArcadeBridge` mirrors it through `web/play/arcade-bridge.js`,
which exposes `window.BreakoutRoyale` on top of the real Little Joy Arcade
client. Signed-in players get cloud saves across devices and trophy reporting;
signed-out players keep playing with a local save. The bridge also enforces the
portrait lock: any landscape window shows a rotate gate, the screen orientation
is requested as portrait on every gesture that can grant it, and the installed
web-app manifest declares `"orientation": "portrait"`.

## Portrait lock

The game is portrait-only, at every size. The canvas is a centred 9:16 column,
landscape shows a rotate gate (desktop included), and `screen.orientation.lock`
is attempted from the first tap.


## Credits

Original assets: Blender-authored models, synthesised audio, generated level
data. Design and code for Little Joy Arcade.
