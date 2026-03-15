# Enclosure Creator Skill — Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a 3-skill Claude Code pipeline that collects parameters via Q&A, generates parametric OpenSCAD enclosure code, and validates/exports STL+PNG — Phase 1 covers core infrastructure + tray-lid template only.

**Architecture:** Three chained Claude Code skills (`enclosure-params` → `enclosure-generate` → `enclosure-validate`) communicating via `enclosure-spec.json`. Each skill is a markdown file defining Claude's behavior. Reference documents (`manufacturing.md`, `extras.md`, `templates/tray-lid.md`) provide domain knowledge for code generation.

**Tech Stack:** Claude Code Skills (markdown), OpenSCAD CLI (validation/export)

**Spec:** `docs/superpowers/specs/2026-03-13-enclosure-creator-skill-design.md`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `skills/enclosure-generate/manufacturing.md` | Shared 3D printing constraints for all box types |
| `skills/enclosure-generate/extras.md` | Add-on features reference (cable hole, label area, mounting ear) |
| `skills/enclosure-generate/templates/tray-lid.md` | Tray + snap-fit lid template — module structure, dimensions, mechanisms |
| `skills/enclosure-params/skill.md` | Parameter collection skill — Q&A flow, validation, JSON output |
| `skills/enclosure-generate/skill.md` | Code generation skill — reads JSON, uses templates, produces .scad |
| `skills/enclosure-validate/skill.md` | Validation + export skill — CLI checks, error fixing, STL/PNG export |

---

## Chunk 1: Reference Documents

### Task 1: Create manufacturing.md

**Files:**
- Create: `skills/enclosure-generate/manufacturing.md`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p skills/enclosure-generate/templates skills/enclosure-params skills/enclosure-validate
```

- [ ] **Step 2: Write manufacturing.md**

Write the shared 3D printing constraints reference file. This is read by `enclosure-generate` skill during code generation.

```markdown
# 3D Printing Manufacturing Constraints

These constraints apply to ALL enclosure types. The code generator MUST follow these rules.

## Wall & Structure

- **Minimum wall thickness:** 2mm (absolute minimum 1.2mm — warn user if below 2mm)
- **Hole tolerance:** Add +0.3mm to all hole diameters (screw holes, cable holes)
- **Tolerance:** +0.5mm per side for PCB fitment (fixed, not user-configurable)

## Geometry Rules

- **Bottom edges:** Use chamfer, NOT fillet (improves bed adhesion)
- **Bridge span:** Maximum 20mm unsupported horizontal span
- **Overhang angle:** Maximum 45° from vertical without supports
- **Design for no supports:** All geometry must be printable without support structures

## Print Settings (Recommendations)

- **Layer height:** 0.2mm recommended
- **Infill:** 20-30% sufficient for enclosures
- **Material:** PLA or PETG

## OpenSCAD Code Rules

- All dimensions defined as top-level variables at file start
- Derived dimensions calculated from base variables (never hardcode derived values)
- Modules take NO parameters — they reference top-level variables
- Comments in English

## Required Modules

Every generated enclosure MUST include:

- `print_layout()` — all parts side-by-side, flat surfaces on print bed, 10mm gap between parts
- `assembly()` — parts in assembled position for visual verification
- Individual part modules (e.g., `tray()`, `lid()`) for single-part export

## Render Mode Block

File must end with a render mode selector:

```openscad
// ============================================
// RENDER MODE
// ============================================
// Uncomment ONE of the following:

print_layout();    // For 3D printing (default)
// assembly();     // For visual assembly check
```

Each individual part module should also be listed as a commented option.
```

- [ ] **Step 3: Commit**

```bash
git add skills/enclosure-generate/manufacturing.md
git commit -m "docs: add manufacturing constraints reference for enclosure generator"
```

---

### Task 2: Create extras.md

**Files:**
- Create: `skills/enclosure-generate/extras.md`

- [ ] **Step 1: Write extras.md**

Write the box-type-agnostic extras reference. Used by code generator when `extras` fields are enabled in spec JSON.

```markdown
# Extras — Add-on Features Reference

These features are box-type agnostic. They are applied AFTER the base enclosure geometry is generated, using `difference()` or `union()` operations.

Each extra is conditional — only generate the code if `extras.<feature>.enabled == true` in the spec.

## Face Coordinate System

Standard face names and their OpenSCAD coordinate mapping:

| Face | Normal Axis | Position | Wall Plane |
|------|-------------|----------|------------|
| `top` | +Z | Z = total_height | XY plane at Z max |
| `bottom` | -Z | Z = 0 | XY plane at Z = 0 |
| `front` | -X | X = 0 | YZ plane at X = 0 |
| `back` | +X | X = outer_length | YZ plane at X max |
| `left` | -Y | Y = 0 | XZ plane at Y = 0 |
| `right` | +Y | Y = outer_width | XZ plane at Y max |

**Important:** If a face is in `open_faces`, that wall doesn't exist. Skip any extra targeting an open face and log a warning.

## Cable Hole

**Spec fields:** `extras.cable_hole.diameter`, `extras.cable_hole.face`

**Implementation:**
- Cylindrical through-hole on the specified face wall
- Hole diameter = `spec.diameter + 0.3` (manufacturing tolerance)
- Position: centered on the face, Z = `wall_thickness + standoff_height + device.height / 2` (mid-height of PCB)
- Use `rotate()` to orient cylinder perpendicular to the target face
- Apply with `difference()` from the enclosure body

**OpenSCAD pattern:**

```openscad
// Cable hole — [face] wall
module cable_hole() {
    hole_d = cable_hole_diameter + 0.3;
    // Position and rotate based on face
    translate([cx, cy, cz])
        rotate([rx, ry, rz])
            cylinder(h = wall_thickness + 2, d = hole_d, center = true, $fn = 32);
}
```

## Label Area

**Spec fields:** `extras.label_area.face`, `extras.label_area.length`, `extras.label_area.width`

**Implementation:**
- Shallow rectangular recess (0.5mm deep) on the specified face
- Position: centered on the face
- Apply with `difference()` from the enclosure body
- For `top` face: recess in lid plate
- For side faces: recess in wall exterior

**OpenSCAD pattern:**

```openscad
// Label recess — [face]
module label_area() {
    // Position based on face, 0.5mm deep into surface
    translate([lx, ly, lz])
        cube([label_length, label_width, 0.5 + 0.01]);
}
```

## Mounting Ear

**Spec fields:** `extras.mounting_ear.hole_diameter`, `extras.mounting_ear.ear_width`

**Implementation:**
- Flanges extending outward from left AND right closed walls (always both sides, symmetric)
- Ear dimensions: `ear_width` wide × `wall_thickness` tall (same height as wall thickness)
- Positioned at mid-length of the wall, at Z = 0 (base level)
- Center hole: `hole_diameter + 0.3mm` tolerance
- Apply with `union()` to the tray body
- Skip if left or right wall is in `open_faces`

**OpenSCAD pattern:**

```openscad
// Mounting ears — left and right walls
module mounting_ears() {
    ear_h = wall_thickness;
    hole_d = mounting_ear_hole_diameter + 0.3;
    ear_w = mounting_ear_width;

    for (side = [0, 1]) {
        y_pos = side == 0 ? -ear_w : outer_width;
        translate([outer_length / 2 - ear_w / 2, y_pos, 0])
            difference() {
                cube([ear_w, ear_w, ear_h]);
                translate([ear_w / 2, ear_w / 2, -1])
                    cylinder(h = ear_h + 2, d = hole_d, $fn = 32);
            }
    }
}
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/enclosure-generate/extras.md
git commit -m "docs: add extras reference for enclosure generator"
```

---

### Task 3: Create tray-lid template

**Files:**
- Create: `skills/enclosure-generate/templates/tray-lid.md`

- [ ] **Step 1: Write tray-lid.md**

Write the tray + snap-fit lid template reference. This is the only template for Phase 1. The code generator reads this to understand the module structure, dimension calculations, and mechanism details.

```markdown
# Tray-Lid Enclosure Template

Two-part enclosure: tray (base + side walls) with snap-fit lid. Screwless assembly.

## Parts

1. **Tray** — base plate + closed side walls + PCB supports + clip recesses
2. **Lid** — flat plate + inner lip (on closed sides) + clip hooks + ventilation grille

## Dimension Calculations

All calculations use spec values. Variable names follow this convention:

```openscad
// --- From spec ---
pcb_length = <device.length>;     // X axis
pcb_width = <device.width>;       // Y axis
pcb_height = <device.height>;     // Z axis (total, components included)
pcb_tolerance = 0.5;              // fixed

// --- Enclosure ---
wall_thickness = <wall_thickness>;
standoff_height = 2;              // PCB bottom clearance
top_clearance = 2;                // above tallest component to lid

// --- Derived internal ---
inner_length = pcb_length + 2 * pcb_tolerance;
inner_width = pcb_width + 2 * pcb_tolerance;
inner_height = standoff_height + pcb_height + top_clearance;

// --- Derived external ---
// Outer dimensions depend on which faces are closed:
// - Closed face adds wall_thickness on each side
// For standard 2-wall (left+right closed, front+back open):
outer_length = inner_length + (front_closed ? wall_thickness : 0) + (back_closed ? wall_thickness : 0);
outer_width = inner_width + (left_closed ? wall_thickness : 0) + (right_closed ? wall_thickness : 0);
tray_height = inner_height;  // cavity height (walls go this high above base plate)

// Total outer Z: wall_thickness (base plate) + tray_height (cavity) + lid_thickness
// Used for bounding box checks:
total_outer_height = wall_thickness + tray_height + lid_thickness;
```

**Note:** `tray_height` is the cavity/wall height above the base plate. The base plate itself adds `wall_thickness` to the total Z. So total enclosure height = `wall_thickness + tray_height + lid_thickness`.

**Dynamic wall logic:** Generate walls ONLY for faces NOT in `open_faces`. The base plate always covers the full outer footprint. Each closed face gets a wall from base to `wall_thickness + tray_height`.

## Snap-Fit Clip Mechanism

Clips connect the lid to the tray. They go on the LONGEST closed walls. If all 4 walls are closed, clips go on the longest pair.

### Parameters

```openscad
clip_width = 5;
clip_height = 3;
clip_hook_depth = 1.5;
clip_tolerance = 0.3;
clip_recess_z_from_top = 1;  // recess starts 1mm below wall top
```

### Tray Side — Recesses

Rectangular cutouts on the INNER face of each clipped wall, near the top:

- **Position Z:** `tray_height - clip_recess_z_from_top - clip_height`
- **Position X:** 2 per wall, at 1/3 and 2/3 of wall length
- **Size:** `(clip_width + clip_tolerance)` × `(clip_hook_depth + clip_tolerance)` × `clip_height`
- Applied with `difference()` from the tray body

### Lid Side — Hooks

Small blocks on the OUTER face of the inner lip, matching recess positions:

- **Position Z:** `-(clip_recess_z_from_top + clip_height)` relative to lid bottom
- **Position X:** Same 1/3 and 2/3 positions as recesses (use shared variables!)
- **Size:** `clip_width` × `clip_hook_depth` × `clip_height`
- Applied with `union()` to the lid body

### Critical Alignment

- Lid inner lip depth MUST be `clip_height + clip_recess_z_from_top` (typically 4mm)
- Use shared `clip_center` variables for both recess and hook X positions
- Recess is slightly oversized (+tolerance), hook is nominal size

## Lid Design

```openscad
lid_thickness = 2;
lid_lip_depth = clip_height + clip_recess_z_from_top;  // typically 4
lid_lip_thickness = 1.5;
```

- **Plate:** full outer footprint × `lid_thickness`
- **Inner lip:** descends `lid_lip_depth` on each closed-wall side
  - Lip runs along the inner face of each clipped wall
  - Width = `lid_lip_thickness` (1.5mm)
  - Length = inner dimension along that axis
- **NO lip on open faces** — lip only on closed walls

## PCB Mounting — Corner Supports

When `mounting == "corner-supports"`:

4 L-shaped supports at PCB corners, inside the tray.

```openscad
support_ledge_width = 2;   // shelf under PCB
support_wall_height = 3;   // side wall gripping PCB edge
support_inset = 2;         // distance from open face edges
support_size = 5;          // footprint along X and Y
```

- **Base module:** models front-left corner (grip walls face +X, +Y)
- **Other corners:** use `mirror()` to flip the base module
  - Back-left: `mirror([1,0,0])`
  - Front-right: `mirror([0,1,0])`
  - Back-right: `mirror([1,0,0]) mirror([0,1,0])`
- Supports are inset from open-face edges by `support_inset`

## PCB Mounting — Other Types

When `mounting == "standoff"`:
- 4 cylindrical posts at PCB corners, height = `standoff_height`
- Optional: top hole for self-tapping screw (M2.5, hole Ø 2.0mm)

When `mounting == "edge-rail"`:
- Two parallel rails along the longest closed walls
- Rail groove: 1.5mm wide × 1mm deep, at `standoff_height` Z
- PCB slides in from an open face

When `mounting == "none"`:
- No mounting features, PCB sits freely on base plate

## Ventilation

### Top Position (`ventilation.position == "top"`)

Through-cut slots in the lid plate:

```openscad
slot_width = 1.5;
bridge_width = 1.5;
num_slots = floor(vent_length / (slot_width + bridge_width));
```

- Grille area: `ventilation.length` × `ventilation.width`
- Centered on the lid plate
- Parallel slots along X axis, evenly spaced
- Slots extend through full `lid_thickness`
- Use `vent_start_offset` to center slots within grille area

### Side Position (`ventilation.position == "side"`)

Through-cut slots on BOTH closed side walls (left + right):

- Same slot/bridge dimensions as top
- Slot area positioned in upper 60% of wall height: Z from `tray_height * 0.4` to `tray_height`
- Slots run along X axis (wall length)
- Grille centered on wall length
- Applied with `difference()` from tray walls

## Module Structure

```openscad
module corner_support() { ... }       // Single L-shaped support (front-left)
module pcb_corner_supports() { ... }  // All 4 corners with mirror()
module clip_recesses() { ... }        // Recess cutouts on tray walls
module tray() { ... }                 // Base + walls + supports - recesses
module lid_clip_hooks() { ... }       // Hook blocks on lid lip
module ventilation_grille() { ... }   // Slot cutouts (top or side)
module lid() { ... }                  // Plate + lip + hooks - ventilation
module print_layout() { ... }         // Tray + flipped lid side by side
module assembly() { ... }             // Tray + lid in assembled position
```

## Print Layout

- **Tray:** as-is, base on print bed (Z=0)
- **Lid:** flipped upside down (`mirror([0,0,1])`) — flat plate on bed, lip faces up
- **Gap:** 10mm between parts along X axis
- **Placement:** `translate([outer_length + 10, 0, lid_thickness]) mirror([0,0,1]) lid();`
```

- [ ] **Step 2: Commit**

```bash
git add skills/enclosure-generate/templates/tray-lid.md
git commit -m "docs: add tray-lid template reference for enclosure generator"
```

---

## Chunk 2: Skill Definitions

### Task 4: Create enclosure-params skill

**Files:**
- Create: `skills/enclosure-params/skill.md`

- [ ] **Step 1: Write enclosure-params/skill.md**

This skill defines the Q&A parameter collection flow. It uses `AskUserQuestion` tool for each question and writes `enclosure-spec.json` at the end.

```markdown
---
name: enclosure-params
description: Collect parameters for a 3D-printable electronics enclosure via interactive Q&A. Produces enclosure-spec.json.
---

# Enclosure Parameter Collection

Collect all parameters needed to generate a 3D-printable electronics enclosure through a step-by-step Q&A flow.

**Announce at start:** "I'm using the enclosure-params skill to collect your enclosure parameters."

## Q&A Flow

Ask questions one at a time using `AskUserQuestion`. Wait for each answer before proceeding.

### Question 1: Device Dimensions

Ask the user for their device/PCB dimensions:

> "What are your device dimensions? Please provide length × width × height in mm. Height should be the TOTAL height including all components (e.g., heatsinks, capacitors)."

- Open-ended question — user types dimensions
- Parse into `device.length` (X), `device.width` (Y), `device.height` (Z)
- Confirm: "So total height {height}mm includes the tallest component, correct?"
- **Validation:** All values must be positive numbers

### Question 2: Box Type

Use `AskUserQuestion` with options:

| Option | Label | Description |
|--------|-------|-------------|
| 1 | Tray + Lid (snap-fit) (Recommended) | Two-part box with snap-fit clips. No screws needed. Best for 3D printing. |
| 2 | Screw Box (Phase 2 — not yet available) | Four corner screws hold the lid. Coming soon. |
| 3 | Sliding Lid (Phase 2 — not yet available) | Lid slides on rails. Coming soon. |
| 4 | Clamshell (Phase 2 — not yet available) | Two halves interlock. Coming soon. |

- If user selects a Phase 2 option, explain it's not yet available and default to tray-lid
- Set `type` field

### Question 3: Open Faces

Use `AskUserQuestion` with multiSelect:

> "Which faces should be left open? (for connector/terminal access)"

| Option | Label | Description |
|--------|-------|-------------|
| 1 | Front (X=0) | Open the front short face |
| 2 | Back (X=max) | Open the back short face |
| 3 | Both front and back | Open both short faces |
| 4 | None — all faces closed | All walls are solid |

- Set `open_faces` array (e.g., `["front", "back"]`)
- Valid values: `front`, `back` (per spec — left/right walls are structural and always closed)

### Question 4: Ventilation

Use `AskUserQuestion`:

> "Does your device need ventilation? (e.g., for heatsinks or hot components)"

| Option | Label | Description |
|--------|-------|-------------|
| 1 | Yes — top ventilation (Recommended) | Grille on the lid, above the hottest component |
| 2 | Yes — side ventilation | Slots on both closed side walls |
| 3 | No ventilation needed | Solid enclosure, no grille |

- If "No": set `ventilation.enabled = false`, skip to Question 5
- If "Yes" (top or side): set `ventilation.position`
- **Cross-validation with open_faces:**
  - If `side` selected and BOTH `left` and `right` are in `open_faces`: warn "Side ventilation requires at least one closed side wall. Disabling ventilation." Set `ventilation.enabled = false`.
  - If `side` selected and only ONE of left/right is open: warn "Side ventilation will only appear on the remaining closed wall."
- Then ask for grille size or offer defaults:
  > "Ventilation grille size? Press enter for defaults or specify length × width in mm."
  - Top default: `device.length * 0.4` × `device.width * 0.4`
  - Side default: `device.length * 0.4` × `(device.height + 4) * 0.4` (where 4 = standoff 2mm + clearance 2mm)

### Question 5: PCB Mounting

Use `AskUserQuestion`:

> "How should the PCB be mounted inside the enclosure?"

| Option | Label | Description |
|--------|-------|-------------|
| 1 | Corner supports (Recommended) | L-shaped ledges grip PCB corners. No screws or holes needed. |
| 2 | Standoffs | Cylindrical posts at corners, optional screw holes |
| 3 | Edge rails | PCB slides in on rails along the longest walls |
| 4 | None | PCB sits freely inside |

- Set `mounting` field

### Question 6: Wall Thickness

Use `AskUserQuestion`:

> "Wall thickness? Default is 2mm (recommended for most enclosures)."

| Option | Label | Description |
|--------|-------|-------------|
| 1 | 2mm (Recommended) | Standard wall thickness, good strength-to-weight ratio |
| 2 | 1.5mm | Thinner walls, lighter but less rigid |
| 3 | 3mm | Thicker walls, maximum strength |

- If user picks custom value < 1.2mm: warn "Walls below 1.2mm may not print reliably."
- If 1.2-2mm: note "Walls below 2mm may be fragile for larger enclosures."
- Set `wall_thickness`

### Question 7: Extras

Use `AskUserQuestion` with multiSelect:

> "Any additional features?"

| Option | Label | Description |
|--------|-------|-------------|
| 1 | Cable hole | Round hole on a wall for cable pass-through |
| 2 | Label area | Flat recessed area for sticking a label |
| 3 | Mounting ears | Flanges with screw holes for wall/panel mounting |
| 4 | None | No extras |

- For each extra NOT selected: set `extras.<feature>.enabled = false`
- For each extra selected: set `extras.<feature>.enabled = true` and ask follow-up questions:
  - **Cable hole:** diameter (default 6mm), which face (front/back/left/right)
  - **Label area:** which face, size (default 40×20mm)
  - **Mounting ears:** hole diameter (default 4mm), ear width (default 10mm)
- Set all `extras` object fields including sub-fields

## Validation Rules

After collecting all parameters, validate:

- All dimensions are positive numbers
- `wall_thickness` ≥ 1.2mm
- Ventilation area does not exceed device dimensions
- If `ventilation.position == "side"` and both `left` and `right` in `open_faces`: warn and set `ventilation.enabled = false`
- Cable hole diameter 2-20mm
- Cable hole face is not in `open_faces` (warn and set `cable_hole.enabled = false`)
- Label area face is not in `open_faces` (warn and set `label_area.enabled = false`)
- If `mounting_ear.enabled == true` and both `left` and `right` in `open_faces`: warn "Mounting ears require at least one closed side wall" and set `mounting_ear.enabled = false`

## Output

1. **Show summary** to user:

```
📋 Enclosure Parameters:
  Device: {length} × {width} × {height} mm
  Type: {type}
  Open faces: {open_faces}
  Ventilation: {enabled} ({position}, {length}×{width}mm)
  Mounting: {mounting}
  Wall thickness: {wall_thickness}mm
  Extras: {list}
```

2. **Ask for confirmation** using `AskUserQuestion`
3. **Write** `enclosure-spec.json` to the project root directory using the Write tool, following this exact schema:

```json
{
  "type": "tray-lid",
  "device": {
    "length": 79,
    "width": 54,
    "height": 16
  },
  "wall_thickness": 2,
  "tolerance": 0.5,
  "mounting": "corner-supports",
  "open_faces": ["front", "back"],
  "ventilation": {
    "enabled": true,
    "position": "top",
    "length": 30,
    "width": 25
  },
  "extras": {
    "cable_hole": {
      "enabled": false,
      "diameter": 6,
      "face": "back"
    },
    "label_area": {
      "enabled": false,
      "face": "top",
      "length": 40,
      "width": 20
    },
    "mounting_ear": {
      "enabled": false,
      "hole_diameter": 4,
      "ear_width": 10
    }
  }
}
```

- `tolerance` is always 0.5 (fixed, never asked)
- Disabled extras still have their default sub-fields but `enabled: false`

## Chaining

After writing the JSON file:

> "Parameters saved to `enclosure-spec.json`. Now generating the OpenSCAD code..."

**REQUIRED:** Invoke the `enclosure-generate` skill using the Skill tool to continue the pipeline.
```

- [ ] **Step 2: Commit**

```bash
git add skills/enclosure-params/skill.md
git commit -m "feat: add enclosure-params skill for Q&A parameter collection"
```

---

### Task 5: Create enclosure-generate skill

**Files:**
- Create: `skills/enclosure-generate/skill.md`

- [ ] **Step 1: Write enclosure-generate/skill.md**

This skill reads the spec JSON and generates OpenSCAD code using template references.

```markdown
---
name: enclosure-generate
description: Generate parametric OpenSCAD enclosure code from enclosure-spec.json. Reads template references and produces enclosure.scad.
---

# Enclosure Code Generator

Generate a complete, parametric OpenSCAD file from the collected enclosure parameters.

**Announce at start:** "I'm using the enclosure-generate skill to create the OpenSCAD code."

## Prerequisites

- `enclosure-spec.json` must exist in the project root (created by `enclosure-params`)
- If file doesn't exist, tell the user to run `enclosure-params` first

## Process

### Step 1: Read Inputs

1. Read `enclosure-spec.json` from the project root
2. Based on `type`, read the matching template:
   - `tray-lid` → read `templates/tray-lid.md` (from this skill's directory)
   - Other types: not yet available (Phase 2)
3. Read `manufacturing.md` (from this skill's directory) for shared constraints
4. If any `extras.<feature>.enabled == true`, read `extras.md` (from this skill's directory)

### Step 2: Generate Code

Using the spec values, template structure, and manufacturing constraints, generate a complete OpenSCAD file.

**Code generation rules:**

- **Generate from scratch** — do NOT copy-paste template code snippets. Use the template as a structural reference to understand what modules are needed and how they connect.
- **All parameters as top-level variables** — no hardcoded values in modules
- **Modules take no parameters** — they reference top-level variables
- **Comments in English** — section headers, variable descriptions, module explanations
- **Follow the template's module structure** exactly — same module names and responsibilities
- **Apply manufacturing constraints** from `manufacturing.md`
- **Integrate extras** from `extras.md` if any are enabled in the spec

**Variable naming convention:**
- Use the spec JSON field names directly: `pcb_length`, `pcb_width`, `pcb_height`
- Prefix derived values: `inner_length`, `outer_length`, `tray_height`
- Extras: `cable_hole_diameter`, `cable_hole_face`, `label_area_face`, etc.

**Dynamic wall generation:**
- Check `open_faces` array to determine which walls to generate
- Base plate always covers full footprint
- Only generate wall geometry for faces NOT in `open_faces`
- Clip positions: only on the longest closed walls

### Step 3: Write Output

Write the generated code to `enclosure.scad` in the project root using the Write tool.

### Step 4: Announce Completion

> "OpenSCAD code generated and saved to `enclosure.scad`. Now validating..."

**REQUIRED:** Invoke the `enclosure-validate` skill using the Skill tool to continue the pipeline.
```

- [ ] **Step 2: Commit**

```bash
git add skills/enclosure-generate/skill.md
git commit -m "feat: add enclosure-generate skill for OpenSCAD code generation"
```

---

### Task 6: Create enclosure-validate skill

**Files:**
- Create: `skills/enclosure-validate/skill.md`

- [ ] **Step 1: Write enclosure-validate/skill.md**

This skill validates the generated code, fixes errors iteratively, and exports STL + PNG.

```markdown
---
name: enclosure-validate
description: Validate OpenSCAD code, fix errors iteratively, and export STL + PNG preview files.
---

# Enclosure Validator & Exporter

Validate the generated OpenSCAD code using the CLI, fix any errors, and produce final output files.

**Announce at start:** "I'm using the enclosure-validate skill to validate and export the enclosure."

## Prerequisites

### OpenSCAD CLI Check

First, check if OpenSCAD is available:

```bash
which openscad 2>/dev/null || ls /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD 2>/dev/null
```

- If found: proceed with full validation + export
- If NOT found: warn user, deliver only `.scad` file, skip STL/PNG steps

> "⚠️ OpenSCAD CLI not found. Delivering the .scad file only. Install OpenSCAD to enable STL export and PNG previews."

### Input File Check

- `enclosure.scad` must exist in the project root
- If not found, tell user to run `enclosure-generate` first

## Validation Loop

Run up to 5 iterations to produce error-free code:

### Each Iteration

**1. Run syntax/geometry check:**

```bash
openscad --hardwarnings -o /dev/null enclosure.scad 2>&1
```

**2. Analyze output:**
- **No errors/warnings** → validation passed, proceed to export
- **Syntax error** → read error message, identify line number and issue, fix the code
- **Warning (with --hardwarnings)** → treat as error, fix
- **Non-manifold warning** → inspect boolean operations, fix intersections

**3. Fix the code:**
- Read the relevant section of `enclosure.scad`
- Apply the fix using the Edit tool
- Log what was changed: "Iteration N: Fixed [description of issue] on line X"

**4. If 5 iterations reached without clean output:**
- Stop fixing
- Report all remaining errors to the user
- Deliver the `.scad` file as-is with the error log

> "⚠️ Validation failed after 5 attempts. Remaining issues: [list]. The .scad file has been saved — you may need to fix these manually."

## Export Phase

After successful validation:

### STL Export

```bash
openscad -o enclosure.stl enclosure.scad
```

- Verify output file exists and is > 0 bytes
- If 0 bytes: geometry error — go back to validation loop

### PNG Preview Export

Generate 4 preview images (1024×768):

```bash
# Isometric view (perspective)
openscad -o enclosure-iso.png --imgsize 1024,768 \
  --autocenter --viewall --projection perspective enclosure.scad

# Front view (orthographic) — looking along Y axis
openscad -o enclosure-front.png --imgsize 1024,768 \
  --autocenter --viewall --camera 0,0,0,0,0,0 --projection ortho enclosure.scad

# Top view (orthographic) — looking down Z axis
openscad -o enclosure-top.png --imgsize 1024,768 \
  --autocenter --viewall --camera 0,0,0,90,0,0 --projection ortho enclosure.scad

# Side view (orthographic) — looking along X axis
openscad -o enclosure-side.png --imgsize 1024,768 \
  --autocenter --viewall --camera 0,0,0,0,0,90 --projection ortho enclosure.scad
```

### Dimension Verification (Optional)

If OpenSCAD is available, verify bounding box dimensions:

1. Temporarily append echo lines to `enclosure.scad`:

```openscad
// Temporary bounding box check
echo("BBOX_X", outer_length);
echo("BBOX_Y", outer_width);
echo("BBOX_Z", wall_thickness + tray_height + lid_thickness);  // Note: corrects spec formula which omits base plate thickness
```

2. Run: `openscad -o /dev/null enclosure.scad 2>&1`
3. Parse `ECHO:` lines from output
4. Compare with expected dimensions from `enclosure-spec.json` (±1mm tolerance)
5. Remove the temporary echo lines from the file
6. If dimensions mismatch: report to user but don't block export

## Output Files

```
enclosure.scad          — OpenSCAD source (parametric)
enclosure.stl           — Print-ready STL (print layout)
enclosure-iso.png       — Isometric preview
enclosure-front.png     — Front view
enclosure-top.png       — Top view
enclosure-side.png      — Side view
```

## Final Report

Present to the user:

```
✅ Enclosure generated and validated!

📦 Box type: {type}
📐 External dimensions: {length} × {width} × {height} mm
🔧 Features: {mounting}, {ventilation}, {extras}

📁 Files:
  • enclosure.scad — OpenSCAD source
  • enclosure.stl — Print-ready STL
  • enclosure-iso.png — Preview

🖨️ Print recommendations:
  • Material: PLA or PETG
  • Layer height: 0.2mm
  • Infill: 20-30%
  • Supports: Not needed
```

Then show the isometric preview using the Read tool:

```
Read enclosure-iso.png
```

## No Chaining

This is the final skill in the pipeline. No further skill invocation is needed.
```

- [ ] **Step 2: Commit**

```bash
git add skills/enclosure-validate/skill.md
git commit -m "feat: add enclosure-validate skill for validation and export"
```

---

### Task 7: End-to-end verification

- [ ] **Step 1: Verify file structure**

```bash
find skills/ -type f | sort
```

Expected output:
```
skills/enclosure-generate/extras.md
skills/enclosure-generate/manufacturing.md
skills/enclosure-generate/skill.md
skills/enclosure-generate/templates/tray-lid.md
skills/enclosure-params/skill.md
skills/enclosure-validate/skill.md
```

- [ ] **Step 2: Verify all files are non-empty and well-formed**

```bash
wc -l skills/enclosure-generate/manufacturing.md
wc -l skills/enclosure-generate/extras.md
wc -l skills/enclosure-generate/templates/tray-lid.md
wc -l skills/enclosure-params/skill.md
wc -l skills/enclosure-generate/skill.md
wc -l skills/enclosure-validate/skill.md
```

All files should have substantial content (>20 lines each).

- [ ] **Step 3: Verify skill frontmatter**

Check that each skill.md has proper YAML frontmatter with `name` and `description` fields:

```bash
head -5 skills/enclosure-params/skill.md
head -5 skills/enclosure-generate/skill.md
head -5 skills/enclosure-validate/skill.md
```

Each should start with `---`, contain `name:` and `description:`, and end with `---`.

- [ ] **Step 4: Verify chaining instructions**

Check that enclosure-params chains to enclosure-generate:
```bash
grep -l "enclosure-generate" skills/enclosure-params/skill.md
```

Check that enclosure-generate chains to enclosure-validate:
```bash
grep -l "enclosure-validate" skills/enclosure-generate/skill.md
```

Check that enclosure-validate has no chaining:
```bash
grep -c "Skill tool" skills/enclosure-validate/skill.md
```
Should return 0 (no outbound skill invocation instruction).

- [ ] **Step 5: Final commit**

```bash
git add -A skills/
git commit -m "feat: complete enclosure creator skill pipeline (Phase 1)"
```
