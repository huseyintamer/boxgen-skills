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

> "OpenSCAD CLI not found. Delivering the .scad file only. Install OpenSCAD to enable STL export and PNG previews."

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

> "Validation failed after 5 attempts. Remaining issues: [list]. The .scad file has been saved — you may need to fix these manually."

## Export Phase

After successful validation:

### STL Export

```bash
openscad -o enclosure.stl enclosure.scad
```

- Verify output file exists and is > 0 bytes
- If 0 bytes: geometry error — go back to validation loop

### PNG Preview Export

Generate 4 preview images (1024x768):

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
4. Compare with expected dimensions from `enclosure-spec.json` (+-1mm tolerance)
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
Enclosure generated and validated!

Box type: {type}
External dimensions: {length} x {width} x {height} mm
Features: {mounting}, {ventilation}, {extras}

Files:
  enclosure.scad — OpenSCAD source
  enclosure.stl — Print-ready STL
  enclosure-iso.png — Preview

Print recommendations:
  Material: PLA or PETG
  Layer height: 0.2mm
  Infill: 20-30%
  Supports: Not needed
```

Then show the isometric preview using the Read tool:

```
Read enclosure-iso.png
```

## No Chaining

This is the final skill in the pipeline. No further skill invocation is needed.
