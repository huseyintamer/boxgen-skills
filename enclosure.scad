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
// PCB CORNER SUPPORTS
// ============================================

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

// ============================================
// CLIP RECESSES
// ============================================
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

            // PCB corner supports
            pcb_corner_supports();
        }
        // Clip recess cutouts
        clip_recesses();
    }
}

// ============================================
// LID CLIP HOOKS
// ============================================
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

// Preview
tray();
