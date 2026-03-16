---
name: enclosure-generate
description: Generate parametric OpenSCAD enclosure code from enclosure-spec.json. Reads template references and produces enclosure.scad.
user-invocable: true
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

**REQUIRED:** Invoke the `boxgen-skills:enclosure-validate` skill using the Skill tool to continue the pipeline.
