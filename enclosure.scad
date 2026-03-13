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

// ============================================
// TRAY MODULE
// ============================================
module tray() {
    difference() {
        union() {
            // Base plate extends under walls (spec's 84x55 is the exposed floor area)
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
