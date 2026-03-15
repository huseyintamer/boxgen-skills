---
name: enclosure-params
description: Collect parameters for a 3D-printable electronics enclosure via interactive Q&A. Produces enclosure-spec.json.
user-invocable: true
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
- `wall_thickness` >= 1.2mm
- Ventilation area does not exceed device dimensions
- If `ventilation.position == "side"` and both `left` and `right` in `open_faces`: warn and set `ventilation.enabled = false`
- Cable hole diameter 2-20mm
- Cable hole face is not in `open_faces` (warn and set `cable_hole.enabled = false`)
- Label area face is not in `open_faces` (warn and set `label_area.enabled = false`)
- If `mounting_ear.enabled == true` and both `left` and `right` in `open_faces`: warn "Mounting ears require at least one closed side wall" and set `mounting_ear.enabled = false`

## Output

1. **Show summary** to user:

```
Enclosure Parameters:
  Device: {length} x {width} x {height} mm
  Type: {type}
  Open faces: {open_faces}
  Ventilation: {enabled} ({position}, {length}x{width}mm)
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

**REQUIRED:** Invoke the `opencad-print:enclosure-generate` skill using the Skill tool to continue the pipeline.
