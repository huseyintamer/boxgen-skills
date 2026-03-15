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
