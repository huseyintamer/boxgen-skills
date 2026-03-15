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
