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
