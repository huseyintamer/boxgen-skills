# OpenCAD Print

AI-powered 3D-printable enclosure generator for electronics projects. Built as a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill pipeline.

Give it your PCB dimensions, answer a few questions, and get a complete parametric [OpenSCAD](https://openscad.org/) file + STL + preview images — ready for 3D printing.

## How It Works

```
/enclosure-params          # Answer 7 questions about your device
        ↓
  enclosure-spec.json      # Parameters saved as JSON
        ↓
/enclosure-generate        # Parametric OpenSCAD code generated
        ↓
  enclosure.scad           # Full .scad source file
        ↓
/enclosure-validate        # CLI validation + export
        ↓
  enclosure.stl + .png     # Print-ready STL + preview images
```

The three skills chain automatically — just run `/enclosure-params` and the pipeline handles the rest.

## Features

- **Interactive Q&A** — guided parameter collection with smart defaults
- **Parametric OpenSCAD output** — all dimensions as variables, easy to customize
- **Multiple mounting options** — corner supports, standoffs, edge rails, or none
- **Snap-fit lid** — no screws needed, clips hold the lid in place
- **Ventilation** — top grille or side wall slots for heat dissipation
- **Extras** — cable holes, label areas, mounting ears
- **Auto-validation** — OpenSCAD CLI checks for errors with up to 5 fix iterations
- **Multi-format export** — `.scad` source + `.stl` for printing + 4x `.png` previews

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [OpenSCAD](https://openscad.org/downloads.html) (for STL/PNG export — optional, `.scad` works without it)

### Option A: Use as a plugin (recommended)

```bash
# Clone the repo
git clone https://github.com/huseyintamer/opencad-print.git

# Use it as a plugin in any project
claude --plugin-dir ./opencad-print
```

Then run:
```
/opencad-print:enclosure-params
```

### Option B: Clone and work inside the repo

```bash
git clone https://github.com/huseyintamer/opencad-print.git
cd opencad-print
claude
```

Then run:
```
/enclosure-params
```

### Usage

1. Start the skill:
   ```
   /enclosure-params
   ```
4. Answer the questions:
   - Device dimensions (length × width × height in mm)
   - Box type (snap-fit tray+lid)
   - Open faces (for connectors)
   - Ventilation (top/side/none)
   - PCB mounting method
   - Wall thickness
   - Extras (cable hole, label area, mounting ears)

5. The pipeline generates your enclosure automatically.

## Example Output

This repo includes a working example: an enclosure for a **TPA3116 mono amplifier board** (79 × 54 × 16mm).

**Parameters used:**
- Open front and back faces (terminal block access)
- Top ventilation grille (heatsink cooling)
- Corner supports (no-screw PCB mounting)
- Snap-fit lid with 4 clips

The generated `enclosure.scad` produces a two-part design (tray + lid) ready for FDM printing without supports.

## Project Structure

```
opencad-print/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest
├── skills/
│   ├── enclosure-params/
│   │   └── SKILL.md              # Q&A parameter collection
│   ├── enclosure-generate/
│   │   ├── SKILL.md              # OpenSCAD code generation
│   │   ├── manufacturing.md      # 3D printing constraints
│   │   ├── extras.md             # Add-on features reference
│   │   └── templates/
│   │       └── tray-lid.md       # Tray + snap-fit lid template
│   └── enclosure-validate/
│       └── SKILL.md              # Validation + STL/PNG export
├── enclosure.scad                # Example: TPA3116 amplifier enclosure
├── device.png                    # Example: TPA3116 board photo
└── docs/
    └── superpowers/
        ├── specs/                # Design specifications
        └── plans/                # Implementation plans
```

## Supported Box Types

| Type | Status | Description |
|------|--------|-------------|
| Tray + Lid (snap-fit) | Available | Two-part, clip-on lid, no screws |
| Screw Box | Phase 2 | Four corner M3 screws |
| Sliding Lid | Phase 2 | Lid slides on rails |
| Clamshell | Phase 2 | Two interlocking halves |

## Customization

The generated `.scad` files are fully parametric. Open in OpenSCAD and adjust any variable at the top of the file:

```openscad
pcb_length = 79;        // Your device length (mm)
pcb_width = 54;         // Your device width (mm)
pcb_height = 16;        // Total height including components
wall_thickness = 2;     // Wall thickness
// ... all dimensions are configurable
```

Render modes at the bottom of the file:

```openscad
print_layout();    // Parts side-by-side for printing (default)
// assembly();     // Visual assembly check
// tray();         // Tray only
// lid();          // Lid only
```

## Print Settings

- **Material:** PLA or PETG
- **Layer height:** 0.2mm
- **Infill:** 20-30%
- **Supports:** Not needed (designed for supportless printing)

## License

MIT
