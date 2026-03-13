# Amplifikatör Kutusu Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a parametric OpenSCAD enclosure (tray + lid) for a TPA3116 amplifier board (79×54×16mm) with snap-fit clips, ventilation, and PCB corner supports.

**Architecture:** Single-file parametric OpenSCAD design (`enclosure.scad`). All dimensions defined as top-level variables. Three modules: `tray()` for the base with walls/supports/clip-slots, `lid()` for the cover with inner lip/hooks/ventilation, and `print_layout()` for print-ready arrangement.

**Tech Stack:** OpenSCAD

**Spec:** `docs/superpowers/specs/2026-03-13-amplifier-enclosure-design.md`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `enclosure.scad` | All parametric variables, tray module, lid module, print_layout module, assembly preview |

---

## Chunk 1: Full Implementation

### Task 1: Create parametric variables and base tray

**Files:**
- Create: `enclosure.scad`

- [ ] **Step 1: Create enclosure.scad with all parametric variables**

Write the file with all top-level variables from the spec. No modules yet — just variables and derived dimensions.

```openscad
// ============================================
// TPA3116 Amplifier Enclosure — Parametric Design
// ============================================

// --- PCB Dimensions ---
pcb_length = 79;        // X axis (mm)
pcb_width = 54;         // Y axis (mm)
pcb_height = 16;        // Z axis — total height including components
pcb_tolerance = 0.5;    // clearance per side

// --- Enclosure ---
wall_thickness = 2;
standoff_height = 2;    // PCB bottom clearance (ledge height)
top_clearance = 2;      // above tallest component to lid

// --- Derived internal dimensions ---
inner_length = pcb_length + 2 * pcb_tolerance;  // 80
inner_width = pcb_width + 2 * pcb_tolerance;    // 55
inner_height = standoff_height + pcb_height + top_clearance; // 20

// --- Derived external dimensions ---
outer_length = inner_length + 2 * wall_thickness;  // 84
outer_width = inner_width + 2 * wall_thickness;    // 59
tray_height = inner_height;  // 20 (walls go full inner height)

// --- Snap-fit clips ---
clip_width = 5;
clip_height = 3;
clip_hook_depth = 1.5;
clip_tolerance = 0.3;
clip_recess_z_from_top = 1;  // recess starts 1mm below wall top

// --- Derived clip positions (shared between tray recesses and lid hooks) ---
clip_center_x1 = outer_length / 3;
clip_center_x2 = 2 * outer_length / 3;

// --- Ventilation ---
vent_x_offset = 22;     // from front edge of inner cavity
vent_y_offset = 14;     // from left edge of inner cavity
vent_length = 30;       // along X
vent_width = 25;        // along Y
slot_width = 1.5;
bridge_width = 1.5;
num_slots = 8;
// Center slots within grille area
vent_slots_total = num_slots * slot_width + (num_slots - 1) * bridge_width; // 22.5
vent_start_offset = (vent_length - vent_slots_total) / 2;  // 3.75

// --- Lid ---
lid_thickness = 2;
lid_lip_depth = 4;       // inner lip descends 4mm (fits clip_height + recess_z_from_top)
lid_lip_thickness = 1.5;

// --- PCB corner supports ---
support_ledge_width = 2;   // shelf under PCB
support_wall_height = 3;   // side wall gripping PCB
support_inset = 2;         // distance from open face edges
support_size = 5;          // footprint of each L-support along X and Y

// --- Print layout ---
print_gap = 10;  // gap between parts in print layout
```

- [ ] **Step 2: Verify variables open correctly in OpenSCAD**

Run: `open -a OpenSCAD enclosure.scad` (macOS) or open manually.
Expected: File opens without errors. No geometry yet — blank preview.

- [ ] **Step 3: Add tray module — base plate + side walls**

Append the tray module. Start with just the base plate and two side walls (no supports or clips yet).

```openscad
// ============================================
// TRAY MODULE
// ============================================
module tray() {
    difference() {
        union() {
            // Base plate: full outer_length x outer_width, wall_thickness tall
            cube([outer_length, outer_width, wall_thickness]);

            // Left wall (Y=0 side)
            cube([outer_length, wall_thickness, tray_height]);

            // Right wall (Y=max side)
            translate([0, outer_width - wall_thickness, 0])
                cube([outer_length, wall_thickness, tray_height]);

            // (corner supports added in Task 2)
        }
        // (clip recesses subtracted in Task 3)
    }
}

// Preview
tray();
```

- [ ] **Step 4: Verify tray base in OpenSCAD**

Open in OpenSCAD, press F5 (preview).
Expected: A U-shaped tray — flat base with two side walls, open front and back. Outer dimensions 84 × 59 × 20mm.

- [ ] **Step 5: Commit initial tray**

```bash
git add enclosure.scad
git commit -m "feat: add parametric variables and base tray (plate + walls)"
```

---

### Task 2: Add PCB corner supports to tray

**Files:**
- Modify: `enclosure.scad`

- [ ] **Step 1: Add corner support module with per-corner orientation**

Each L-shaped support has grip walls that face **inward** toward the PCB center. Use `mirror()` to orient each corner correctly. A single `corner_support()` module defines the front-left shape, then mirror transforms create the other 3 corners.

Add this module before `tray()`:

```openscad
// Single L-shaped corner support — models front-left corner
// Grip walls face +X and +Y (inward toward PCB center)
// Origin: outer corner of the support footprint
module corner_support() {
    // Ledge (shelf under PCB)
    cube([support_size, support_size, standoff_height]);
    // Grip wall along Y (faces +X, grips PCB X-edge)
    cube([support_ledge_width, support_size, standoff_height + support_wall_height]);
    // Grip wall along X (faces +Y, grips PCB Y-edge)
    cube([support_size, support_ledge_width, standoff_height + support_wall_height]);
}

module pcb_corner_supports() {
    // PCB cavity origin: (wall_thickness, wall_thickness)
    // Supports inset from open faces by support_inset
    x_inner_min = wall_thickness + support_inset;
    x_inner_max = wall_thickness + inner_length - support_inset;
    y_inner_min = wall_thickness;
    y_inner_max = wall_thickness + inner_width;

    // Front-left: grip walls face +X, +Y (default orientation)
    translate([x_inner_min, y_inner_min, wall_thickness])
        corner_support();

    // Back-left: grip walls face -X, +Y (mirror on X)
    translate([x_inner_max, y_inner_min, wall_thickness])
        mirror([1, 0, 0])
            corner_support();

    // Front-right: grip walls face +X, -Y (mirror on Y)
    translate([x_inner_min, y_inner_max, wall_thickness])
        mirror([0, 1, 0])
            corner_support();

    // Back-right: grip walls face -X, -Y (mirror on X and Y)
    translate([x_inner_max, y_inner_max, wall_thickness])
        mirror([1, 0, 0])
            mirror([0, 1, 0])
                corner_support();
}
```

Add `pcb_corner_supports();` call inside the `union()` block of `tray()`.

- [ ] **Step 2: Verify corner supports in OpenSCAD**

Press F5 in OpenSCAD. Inspect each corner:
- Front-left: grip walls point toward center (+X, +Y)
- Back-left: grip walls point toward center (-X, +Y)
- Front-right: grip walls point toward center (+X, -Y)
- Back-right: grip walls point toward center (-X, -Y)

Expected: 4 L-shaped posts, each gripping their respective PCB corner inward.

- [ ] **Step 3: Commit corner supports**

```bash
git add enclosure.scad
git commit -m "feat: add PCB corner supports with correct per-corner orientation"
```

---

### Task 3: Add snap-fit clip recesses to tray walls

**Files:**
- Modify: `enclosure.scad`

- [ ] **Step 1: Add clip recess cutouts to tray**

Add rectangular recesses (cutouts) to the inner face of each side wall. 2 per wall, using shared center positions. Recesses are 1mm below wall top edge.

Add this module before `tray()`:

```openscad
module clip_recesses() {
    recess_width = clip_width + clip_tolerance;
    recess_height = clip_height;
    recess_depth = clip_hook_depth + clip_tolerance;

    // Z position: top of wall minus offset minus height
    recess_z = tray_height - clip_recess_z_from_top - recess_height;

    // X positions: centered on shared clip center points
    for (cx = [clip_center_x1, clip_center_x2]) {
        x_pos = cx - recess_width / 2;

        // Left wall (Y=0): recess on inner face
        translate([x_pos, wall_thickness - recess_depth, recess_z])
            cube([recess_width, recess_depth, recess_height]);

        // Right wall (Y=max): recess on inner face
        translate([x_pos, outer_width - wall_thickness, recess_z])
            cube([recess_width, recess_depth, recess_height]);
    }
}
```

Add `clip_recesses();` inside the `difference()` block of `tray()` (as a subtraction).

- [ ] **Step 2: Verify clip recesses in OpenSCAD**

Press F5. Use View > Cut (cross-section) to inspect the inner wall surface near the top.
Expected: 4 rectangular notches on the inner faces of the side walls, evenly spaced at 1/3 and 2/3 along the 84mm length, positioned 1mm below the wall top edge.

- [ ] **Step 3: Commit clip recesses**

```bash
git add enclosure.scad
git commit -m "feat: add snap-fit clip recesses to tray walls"
```

---

### Task 4: Create lid module — plate + inner lip + clip hooks

**Files:**
- Modify: `enclosure.scad`

- [ ] **Step 1: Add clip hooks module**

Hooks are outward-facing bumps on the inner lip. They align with tray recesses using shared center positions. Hook top aligns with recess top (1mm below wall top = 1mm below lid plate bottom).

Add this module before `lid()`:

```openscad
module lid_clip_hooks() {
    hook_width = clip_width;
    hook_height = clip_height;
    hook_depth = clip_hook_depth;

    // Z position: hook top at -clip_recess_z_from_top (1mm below lid plate bottom)
    // hook bottom at -(clip_recess_z_from_top + clip_height) = -4
    hook_z = -(clip_recess_z_from_top + clip_height);

    // X positions: centered on shared clip center points
    for (cx = [clip_center_x1, clip_center_x2]) {
        x_pos = cx - hook_width / 2;

        // Left lip hooks — face outward toward Y=0 (toward wall)
        translate([x_pos, wall_thickness - hook_depth, hook_z])
            cube([hook_width, hook_depth, hook_height]);

        // Right lip hooks — face outward toward Y=max (toward wall)
        translate([x_pos, outer_width - wall_thickness, hook_z])
            cube([hook_width, hook_depth, hook_height]);
    }
}
```

- [ ] **Step 2: Add lid module with plate and inner lip**

The lid plate is `outer_length × outer_width × lid_thickness`. Inner lips descend 4mm from left and right edges, fitting inside the tray walls.

```openscad
// ============================================
// LID MODULE
// ============================================
module lid() {
    union() {
        // Lid plate
        cube([outer_length, outer_width, lid_thickness]);

        // Inner lip — left side (Y=0)
        translate([wall_thickness, wall_thickness, -lid_lip_depth])
            cube([inner_length, lid_lip_thickness, lid_lip_depth]);

        // Inner lip — right side (Y=max)
        translate([wall_thickness, outer_width - wall_thickness - lid_lip_thickness, -lid_lip_depth])
            cube([inner_length, lid_lip_thickness, lid_lip_depth]);

        // Clip hooks on inner lips
        lid_clip_hooks();
    }
}
```

- [ ] **Step 3: Verify lid in OpenSCAD**

Comment out `tray();` and add `lid();`. Press F5.
Expected: A flat plate with two inner lip rails descending 4mm on left/right edges, and 4 small hook bumps on the lips. Hooks are 3mm tall, positioned with top at 1mm below plate bottom.

- [ ] **Step 4: Verify hook-recess alignment**

Switch to `assembly();` (or manually position: `tray(); translate([0,0,tray_height]) lid();`). Press F5.
Check: Hooks should nest inside tray wall recesses. Both span the same Z range in assembled coordinates:
- Recess: Z=16 to Z=19 (tray coords)
- Hook: lid Z = -(1+3) = -4 to -1, assembled = tray_height + hook_z = 20-4=16 to 20-1=19

Expected: Perfect Z-alignment. Hooks fully inside recesses.

- [ ] **Step 5: Commit lid**

```bash
git add enclosure.scad
git commit -m "feat: add lid module with inner lip and aligned snap-fit hooks"
```

---

### Task 5: Add ventilation grille to lid

**Files:**
- Modify: `enclosure.scad`

- [ ] **Step 1: Add ventilation grille module**

Through-cut slots on the lid plate, centered within the grille area over the heatsink.

Add this module before `lid()`:

```openscad
module ventilation_grille() {
    // Grille position on lid (relative to lid origin = tray outer origin)
    grille_x = wall_thickness + vent_x_offset;
    grille_y = wall_thickness + vent_y_offset;

    // Create through-cut slots, centered within grille area
    for (i = [0 : num_slots - 1]) {
        slot_x = grille_x + vent_start_offset + i * (slot_width + bridge_width);
        translate([slot_x, grille_y, -1])
            cube([slot_width, vent_width, lid_thickness + 2]);
    }
}
```

- [ ] **Step 2: Update lid module to use difference for ventilation**

Replace the `lid()` module's `union()` with a `difference()` wrapping:

```openscad
module lid() {
    difference() {
        union() {
            // Lid plate
            cube([outer_length, outer_width, lid_thickness]);

            // Inner lip — left side
            translate([wall_thickness, wall_thickness, -lid_lip_depth])
                cube([inner_length, lid_lip_thickness, lid_lip_depth]);

            // Inner lip — right side
            translate([wall_thickness, outer_width - wall_thickness - lid_lip_thickness, -lid_lip_depth])
                cube([inner_length, lid_lip_thickness, lid_lip_depth]);

            // Clip hooks
            lid_clip_hooks();
        }
        // Ventilation cutouts
        ventilation_grille();
    }
}
```

- [ ] **Step 3: Verify ventilation in OpenSCAD**

Preview lid with F5.
Expected: 8 horizontal slots centered within the grille area on the lid surface. Slots are through-cuts (visible when looking at lid from below).

- [ ] **Step 4: Commit ventilation**

```bash
git add enclosure.scad
git commit -m "feat: add ventilation grille to lid"
```

---

### Task 6: Add print layout and assembly preview

**Files:**
- Modify: `enclosure.scad`

- [ ] **Step 1: Add print_layout module**

Both parts side by side, flat surfaces on print bed. Lid is flipped upside down (lip facing up).

```openscad
// ============================================
// PRINT LAYOUT
// ============================================
module print_layout() {
    // Tray: as-is, base on print bed
    tray();

    // Lid: flipped upside down, placed next to tray
    translate([outer_length + print_gap, 0, lid_thickness])
        mirror([0, 0, 1])
            lid();
}
```

- [ ] **Step 2: Add assembly preview module**

Shows lid positioned on top of tray for visual verification.

```openscad
// ============================================
// ASSEMBLY PREVIEW
// ============================================
module assembly() {
    tray();

    // Lid on top of tray
    translate([0, 0, tray_height])
        lid();
}
```

- [ ] **Step 3: Add render mode selector at end of file**

Remove any earlier standalone `tray();` or `lid();` calls. Add at end of file:

```openscad
// ============================================
// RENDER MODE
// ============================================
// Uncomment ONE of the following:

print_layout();    // For 3D printing (default)
// assembly();     // For visual assembly check
// tray();         // Tray only
// lid();          // Lid only
```

- [ ] **Step 4: Verify print layout in OpenSCAD**

Press F5 with `print_layout()` active.
Expected: Tray on the left, lid flipped on the right, 10mm gap between them. Both have flat bottoms touching Z=0.

- [ ] **Step 5: Verify assembly view**

Comment `print_layout()`, uncomment `assembly()`. Press F5.
Expected: Lid sits on top of tray. Inner lips (4mm deep) nest inside walls. Hooks align with recesses. Closed box with ventilation slots on top. Total height: 22mm.

- [ ] **Step 6: Commit layout and preview**

```bash
git add enclosure.scad
git commit -m "feat: add print layout and assembly preview modes"
```

---

### Task 7: Final verification

- [ ] **Step 1: Verify all dimensions**

In OpenSCAD with `assembly()` active, use `View > Show Edges` and measure:
- Total outer dimensions: 84 × 59 × 22mm
- Tray height: 20mm
- Lid thickness: 2mm
- Ventilation slots visible on top
- Clip hooks seated in recesses
- PCB corner supports gripping inward at all 4 corners

- [ ] **Step 2: Export STL for print test**

Switch to `print_layout()` and render (F6), then export:
```
File > Export > STL > enclosure-print.stl
```

- [ ] **Step 3: Final commit**

```bash
git add enclosure.scad
git commit -m "feat: complete amplifier enclosure — ready for 3D printing"
```
