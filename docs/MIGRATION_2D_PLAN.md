# TITO — Comprehensive 2D Architecture & Migration Plan

**Goal:** move the project from GL-Compat 3D scenes to a **pure 2D stylized
action-platformer** (graphic-novel neo-noir, *Mark of the Ninja* silhouette
readability), keeping all gameplay IP we already built (smart enemy AI,
boss design, cinematics, gamepad/Input-Helper stack, Arabic/EN presentation).

**Terminology (project-wide, filter-safe):** opponents are *enforcers /
sentries / marksmen* of a fictional Syndicate; combat outcomes are
*defeats*, *stuns*, *vitality depletion*; no real-world weapons or real
agencies anywhere in code or assets.

---

## 1. What gets archived (3D retirement) vs. what survives

Nothing is deleted from Git history — 3D is **archived in-repo** so the
project opens clean and 2D-first.

| 3D asset / system (today) | Fate | 2D counterpart |
|---|---|---|
| `player/tito.tscn`, `tito_body.gd` (CharacterBody3D, GLB anims) | archive → `legacy3d/player/` | `core2d/actors/player_2d.tscn` (CharacterBody2D + AnimatedSprite2D) |
| `enemies/enemy.tscn`, `tito_enemy.gd` (+ subclasses, `boss_ghorab.gd`) | archive → `legacy3d/enemies/` | `core2d/actors/enemy_2d.gd` ports the *_same AI brain_* (PATROL/CHASE/SEARCH/ATTACK/STAGGER, vision cone, hearing, "!" indicators) |
| `levels/cairo_builder.gd`, `cairo_night.tscn`, `prologue_builder.gd`, `prologue_escape.tscn` | archive → `legacy3d/levels/` | `levels2d/chapter1/…`, `levels2d/prologue/…` built by a new zone-builder with the same code-driven philosophy |
| `world/parallax_layer.gd`, `rope.tscn`, `checkpoint/deathzone/endzone.tscn` | archive | native `ParallaxBackground` + `world2d/*.tscn` (Marker2D checkpoints, HazardZone2D, Ladder2D) |
| `physics/Jolt` (`project.godot [physics]`) | removed line | default Godot Physics 2D |
| PBR-material pipeline (`tools/gen_*_art.py`) | **kept + extended** | outputs become **2D sprite sheets + normal maps** (PNG already; normal maps drive `PointLight2D` shading) |
| `combat/tito_health.gd` (Node, dimension-agnostic) | **kept as-is** | shared by all 2D actors |
| `addons/input_helper` + InputMap (keyboard+gamepad) | **kept as-is** | untouched — input is dimension-agnostic |
| Device-aware hint system (built last session) | ported (Label → Label2D/Control) | same `_refresh_hints(device)` idea |
| Cinematic overlay system (dialogue/flash/ECG) | ported to `ui2d/` CanvasLayer | same sequence logic, 2D fonts |
| `tools/lint_gd.py`, mock renderers, fonts | kept | extended for 2D sheet checks |
| `tests/*.tscn` (3D smoke/mission) | archived; new `tests2d/smoke2d.tscn` in Phase 10 | |

Renderer stays **GL Compatibility** — 2D lights, canvas shaders,
GPUParticles2D all work there; "volumetric" looks are faked with layered
alpha sprites (explicitly documented, no false claims).

---

## 2. New 2D core architecture

### 2.1 Directory layout
```
core2d/
  actors/   player_2d.gd/.tscn, enemy_2d.gd, boss_raven_2d.gd
  combat2d/ hitbox_2d.gd, hurtbox_2d.gd   (Area2D pair; Health reused)
  world2d/  oneway_platform.tscn, checkpoint_2d, hazard_zone_2d,
            ladder_2d, bounce_car.tscn, gate_2d
  fx2d/     rain_2d.tscn, wind_streaks, dust_motes, paper_scraps,
            reflection_strip.gd, flicker_light_2d.gd
  ui2d/     dialogue_layer.tscn, tutorial_prompts.gd, boss_bar.tscn,
            vitality_hud.tscn
levels2d/
  prologue/prologue_2d.tscn + zones/zone_builder_2d.gd + zone_1..5 scripts
  chapter1/chapter1.tscn (stub for outro target)
assets2d/
  sprites/ (player, enforcers, raven, props — atlases + _n normals)
  tiles/ (street/brick TileSet + _n), fx/, audio/
docs/ (this plan, tuning tables)
legacy3d/ (everything retired)
```

### 2.2 Units & physics (tuning contract)
- **PPU 32** (1 "design metre" ≈ 32 px). Player capsule ≈ 30×56 px.
- Physics layers (mirrors the 3D scheme):
  `1 world · 2 player body · 4 enemy hurtbox · 8 enemy body ·
  16 player hitbox · 32 hazards · 64 triggers`.
- Movement constants (start values, tuned in Phase 9):

| action | value |
|---|---|
| run / sprint | 190 / 290 px·s⁻¹ (sprint after 0.8 s hold) |
| accel / friction (ground) | 1400 / 1700 |
| gravity / max fall | 1450 / 640 |
| jump speed (apex ≈ 2.6 m) | 560, variable (cut to 40% on release) |
| coyote / jump buffer | 0.11 s / 0.12 s |
| slide | burst 420 → 180, hitbox 30×20, 0.45 s |
| dash-roll | 360 px, 0.28 s, **i-frames 0.22 s** |
| wall-slide / wall-jump | fall cap 90; push 380·x + 520·y, 0.16 s input lock |
| ground-pound | stall 0.08 s then −900·y, shockwave hitbox on land |
| parry window | 0.18 s from press; success = 0.35 s world slowdown + riposte bonus |
| hitstop on connect | 0.06–0.09 s |

- Player states: `STAGGER→IDLE/RUN/SPRINT/JUMP/FALL/WALL_SLIDE/SLIDE/ROLL/
  PARRY/LIGHT1..3/HEAVY/POUND/HURT/CLIMB/STUNNED/DEAD` — single enum +
  `_enter/_exit/_update` per state (proven pattern from our 3D enemies).
- Combat: `HitBox2D(Area2D, layer 16)` enabled only during active frames
  via AnimationPlayer method tracks — no polling; `HurtBox2D (layer 4)`
  routes to `TitoHealth.take_damage`. Parry is a timed HurtBox flag:
  while active, incoming damage → `parried` event instead.

### 2.3 Animation pipeline
- `AnimatedSprite2D` + one `AnimationPlayer` per actor (drives frames,
  hitbox windows, squash/stretch, sfx cues, and particle bursts).
- **Placeholder art first:** ink-style vector silhouettes generated by our
  PIL/numpy tools into sprite atlases (+ auto `_n` normal maps from
  height = alpha dilation) — rig-correct, style-consistent, replaceable
  by hand-drawn sheets later with zero code changes (same frame names).
- Boss telegraphs are **readable silhouettes + indicator sprites**
  ("!", stance glows, warning beams) — same philosophy as 3D build.

### 2.4 The 7-layer parallax stack (native nodes)
`ParallaxBackground` root; each `ParallaxLayer.motion_scale`
calibrated (and limits set so nothing tears at zone edges):

| # | layer | motion_scale | content (per art brief) |
|---|---|---|---|
| 1 | Distant Sky | 0.04 | moody night sky, slow cloud silhouettes drifting |
| 2 | Far Skyline | 0.16 | vintage rooftops, water towers, radio antennas (dark) |
| 3 | Mid | 0.34 | weathered brick facades, laundry lines (wind-animated), AC units with drip FX |
| 4 | Near | 0.60 | street cafe facades, tables, parked vintage cars w/ exhaust puffs |
| 5 | PLAYABLE | 1.00 | platforms/colliders: bounce sedans, canopies, market stands, emergency ladders, curb obstacles, slide pipes |
| 6 | Foreground | 1.28 | occluding silhouettes: utility lines, lamp posts, drifting smoke wisps |
| 7 | Lighting Overlay | (CanvasLayer, no scroll) | `CanvasModulate` deep-blue grade, `PointLight2D` amber pools + hazard indicators, lightning flashes, rain streaks, fake fog sheets |

Dynamic FX distributed: dust motes (layers 3–5), paper scraps (5),
wind streaks (6), street reflections = mirrored copy of lit sprites
drawn onto a wet-ground strip with a cheap canvas wobble shader.

### 2.5 Camera
`Camera2D`: smoothing 6 px lookahead toward input, per-zone
`limit_*`, boss-arena lock + slight zoom (0.92) on fight start, tiny
shake API (trauma-based) shared with rumble events.

### 2.6 UI / presentation
- `ui2d/dialogue_layer` — top/bottom bars, AR + EN, typewriter option,
  speaker tint; ported sequences (below) using the **new approved lines**.
- `ui2d/tutorial_prompts` — world-anchored prompts, device-aware via the
  Input Helper exactly like the current hint system (kbd/xbx/PS text).
- `ui2d/vitality_hud` — player vitality pips; `ui2d/boss_bar` for Raven.
- Fonts stay DejaVu (Arabic OK) until the comic font asset lands.

### 2.7 Audio (generated placeholders, Phase 8–9)
numpy→WAV synth pack: jump/land, staff whoosh, parry *clang*, slide,
smoke hiss, beam hum, gate breach rumble, rain+bazaar room-tones,
siren loop, heartbeat → flatline beep, and the **climax cue**
(high-beam swell + reel-rewind whoosh). All procedural, replaceable.

---

## 3. Prologue content plan (Zones + Raven) — 2D build

Same five-zone tutorial ramp and duel, restated with 2D verbs
(slide replaces crawl-under, wall-jump added, roll/parry/pound are real
mechanics — see input additions below).

- **Zone 1 — Traversal:** staggered winded intro → sprint; damaged
  roller shutter = **low-slide gap**; narrow shaft = **wall-jump** pair
  of brick walls; siren light pools (PointLight2D, red/blue alternate).
- **Zone 2 — Staff Enforcer:** patrol with wooden staff; prompts teach
  light×3 chain, heavy, and **parry** vs his overhead (clear windup).
- **Zone 3 — Shield Sentry:** full-body barrier deflects frontal hits;
  prompts teach **dash-roll through / behind** + **aerial ground-pound**.
- **Zone 4 — Hazards:** Smoke unit drops grounded hazard canisters
  (HazardZone2D, tick vitality drain) pushing canopy platforming;
  Marksman paints a **warning beam** (Line2D + light) then fires —
  slide/roll timing dodges the chest-line shot.
- **Zone 5 — Perimeter Arena:** mixed wave (staff ×2, shield ×1,
  marksman ×1) around barricades; all defeated → gate opens → rooftop.
- **Raven duel** (rooftop, floodlights, suspended girders):
  - P1: 3-shot volley (slide, slide, jump) → staff rush (parry or vault
    → recovery punish) → 2 s vulnerability stance.
  - P2 (<40%): support beam-grid sweep (safe only airborne or on
    girders), leap slam with twin floor shockwaves (jump), defensive
    stance (attacking in = immediate evasive toss).
- **Climax:** vitality depleted → confrontation cinematic → high-beam
  white sweep + audio cue → hard black → reel-rewind → VO:
  *"To understand the ending... you have to return to where the story
  truly began."* → `levels2d/chapter1/chapter1.tscn`.

**Dialogue (approved, kept verbatim; AR track added alongside):**
- Raven: "You think you can just walk away? You were built by this
  system, and you end with it."
- Tito: "I took responsibility for my path... now you answer for yours."

### Input additions (InputMap, keyboard + pad, Input-Helper aware)
| action | keyboard | pad |
|---|---|---|
| attack_light | J | X / Square |
| attack_heavy | K | Y / Triangle |
| parry | L | RB / R1 |
| dash_roll | Shift | B / Circle |
| slide | Ctrl (tap=dash? — no: keep) → **hold while running** | RT / R2 (hold) |
Existing keys stay (move/jump/climb/reset). Old `attack`/`crawl` actions
are aliased so legacy scenes don't break during transition.

---

## 4. Implementation phases (sequential, each self-verifying)

1. **P0 Repo prep:** `legacy3d/` move, remove Jolt + 3D main scene,
   new empty `levels2d/boot.tscn` as main scene, asset dir scaffold,
   lint tool updated. *Check: project opens 2D-clean, no res errors.*
2. **P1 Core body:** Player CharacterBody2D (run/jump/coyote/variable),
   Camera2D, `tests2d/smoke2d.tscn` greybox + TileSet street/brick.
3. **P2 Traversal moves:** slide, wall-slide/jump, roll; Zone 1 layout.
4. **P3 Combat core:** HitBox/HurtBox 2D, vitality HUD, light×3/heavy,
   hitstop, parry; Staff Enforcer AI port; Zone 2.
5. **P4 Shield Sentry + ground-pound; Zone 3.**
6. **P5 HazardZone2D (smoke), Marksman beam; Zone 4 canopy route.**
7. **P6 Arena wave + gate unlock; Zone 5 + checkpoint/respawn 2D.**
8. **P7 Raven boss (both phases) + rooftop arena + boss bar.**
9. **P8 Cinematics:** staggered intro, dialogue layer, outro climax
   (high-beams → black → rewind → VO) → Chapter 1 stub transition.
10. **P9 Art pass:** all 7 layers dressed, boilerplate FX set (dust,
    paper, wind, reflections), lighting overlay, generated SFX pack,
    thunder/lightning overlay.
11. **P10 Polish & hardening:** tuning pass on the Phase-2 table,
    trauma shake + rumble mapping, perf review (light count budget),
    `tests2d` regression, README + dev docs update.

Each phase lands as its own commit on this branch; PIL mock renders of
major zones accompany art phases so style is reviewable before engine
wiring (same workflow we used for the 3D mocks).

---

## 5. Open decisions (defaults chosen; override freely)

1. **Placeholder art:** proceed with generated ink-silhouette atlases
   (recommended) → swap with commissioned sheets later unchanged.
2. **Archive (recommended) vs delete `legacy3d/`** at the very end.
3. **Buttons:** parry=RB/L, roll=B/Shift, heavy=Y/K, slide=RT/Ctrl-hold.
4. **Chapter 1 outro target:** fresh 2D rebuild of Wasat-El-Balad.
5. **Arabic dialogue track:** I'll author Egyptian AR for the new
   approved lines (approved EN stays the subtitle line).
6. **TileMap for dressing collision-free streets; code-built
   StaticBody2D for anything gameplay-relevant** (keeps our builder
   workflow and deterministic layouts).

*Prepared 2026-09-10 — plan review gate: no code/asset generation until
this document is approved.*
