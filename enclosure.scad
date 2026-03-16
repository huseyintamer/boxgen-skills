// ============================================
// Electronics Enclosure — Parametric Design
// ============================================

// --- PCB Dimensions ---
pcb_length = 18.0;      // X axis (mm)
pcb_width = 25.5;       // Y axis (mm)
pcb_height = 3.1;       // Z axis — total height including components
pcb_tolerance = 0.5;    // clearance per side

// --- Enclosure ---
wall_thickness = 2;
standoff_height = 2;    // PCB bottom clearance (ledge height)
top_clearance = 2;      // above tallest component to lid

// --- Derived internal dimensions ---
inner_length = pcb_length + 2 * pcb_tolerance;  // 19
inner_width = pcb_width + 2 * pcb_tolerance;    // 26.5
inner_height = standoff_height + pcb_height + top_clearance; // 7.1

// --- Open faces: front (X=0) and back (X=max) ---
// Left (Y=0) and right (Y=max) walls are closed

// --- Derived external dimensions ---
// Front and back are open, so no wall_thickness added on X axis
outer_length = inner_length;                       // 19
outer_width = inner_width + 2 * wall_thickness;    // 30.5
tray_height = inner_height;                        // 7.1

// --- Snap-fit clips (on left and right walls — longest closed walls) ---
clip_width = 5;
clip_height = 3;
clip_hook_depth = 1.5;
clip_tolerance = 0.3;
clip_recess_z_from_top = 1;

// --- Derived clip positions (shared between tray recesses and lid hooks) ---
clip_center_x1 = outer_length / 3;
clip_center_x2 = 2 * outer_length / 3;

// --- Ventilation (top) ---
vent_length = 7.2;      // along X
vent_width = 10.2;      // along Y
slot_width = 1.5;
bridge_width = 1.5;
num_slots = floor(vent_length / (slot_width + bridge_width));  // 2
vent_slots_total = num_slots * slot_width + (num_slots - 1) * bridge_width;
vent_start_offset = (vent_length - vent_slots_total) / 2;

// --- Lid ---
lid_thickness = 2;
lid_lip_depth = clip_height + clip_recess_z_from_top;  // 4
lid_lip_thickness = 1.5;

// --- PCB corner supports ---
support_ledge_width = 2;
support_wall_height = 3;
support_inset = 2;      // distance from open face edges
support_size = 5;

// --- Cable hole (left wall) ---
cable_hole_diameter = 6;
cable_hole_tolerance = 0.3;

// --- Mounting ears (left and right walls) ---
mounting_ear_hole_diameter = 4;
mounting_ear_width = 10;

// --- Print layout ---
print_gap = 10;

// ============================================
// PCB CORNER SUPPORTS
// ============================================

// Single L-shaped corner support — models front-left corner
// Grip walls face +X and +Y (inward toward PCB center)
module corner_support() {
    // Ledge (shelf under PCB)
    cube([support_size, support_size, standoff_height]);
    // Grip wall along Y (faces +X, grips PCB X-edge)
    cube([support_ledge_width, support_size, standoff_height + support_wall_height]);
    // Grip wall along X (faces +Y, grips PCB Y-edge)
    cube([support_size, support_ledge_width, standoff_height + support_wall_height]);
}

module pcb_corner_supports() {
    // PCB cavity origin: (0, wall_thickness) since front/back are open
    x_inner_min = support_inset;
    x_inner_max = inner_length - support_inset;
    y_inner_min = wall_thickness;
    y_inner_max = wall_thickness + inner_width;

    // Front-left: grip walls face +X, +Y
    translate([x_inner_min, y_inner_min, wall_thickness])
        corner_support();

    // Back-left: grip walls face -X, +Y
    translate([x_inner_max, y_inner_min, wall_thickness])
        mirror([1, 0, 0])
            corner_support();

    // Front-right: grip walls face +X, -Y
    translate([x_inner_min, y_inner_max, wall_thickness])
        mirror([0, 1, 0])
            corner_support();

    // Back-right: grip walls face -X, -Y
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

    recess_z = tray_height - clip_recess_z_from_top - recess_height;

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
// CABLE HOLE
// ============================================
module cable_hole() {
    hole_d = cable_hole_diameter + cable_hole_tolerance;
    // Left wall (Y=0), centered on X, at PCB mid-height
    hole_z = wall_thickness + standoff_height + pcb_height / 2;
    hole_x = outer_length / 2;
    translate([hole_x, -1, hole_z])
        rotate([-90, 0, 0])
            cylinder(h = wall_thickness + 2, d = hole_d, $fn = 32);
}

// ============================================
// MOUNTING EARS
// ============================================
module mounting_ears() {
    ear_h = wall_thickness;
    hole_d = mounting_ear_hole_diameter + 0.3;
    ear_w = mounting_ear_width;

    // Left ear (Y=0, extends in -Y direction)
    translate([outer_length / 2 - ear_w / 2, -ear_w, 0])
        difference() {
            cube([ear_w, ear_w, ear_h]);
            translate([ear_w / 2, ear_w / 2, -1])
                cylinder(h = ear_h + 2, d = hole_d, $fn = 32);
        }

    // Right ear (Y=outer_width, extends in +Y direction)
    translate([outer_length / 2 - ear_w / 2, outer_width, 0])
        difference() {
            cube([ear_w, ear_w, ear_h]);
            translate([ear_w / 2, ear_w / 2, -1])
                cylinder(h = ear_h + 2, d = hole_d, $fn = 32);
        }
}

// ============================================
// TRAY MODULE
// ============================================
module tray() {
    difference() {
        union() {
            // Base plate
            cube([outer_length, outer_width, wall_thickness]);

            // Left wall (Y=0 side)
            cube([outer_length, wall_thickness, wall_thickness + tray_height]);

            // Right wall (Y=max side)
            translate([0, outer_width - wall_thickness, 0])
                cube([outer_length, wall_thickness, wall_thickness + tray_height]);

            // PCB corner supports
            pcb_corner_supports();

            // Mounting ears
            mounting_ears();
        }
        // Clip recess cutouts
        clip_recesses();

        // Cable hole on left wall
        cable_hole();
    }
}

// ============================================
// LID CLIP HOOKS
// ============================================
module lid_clip_hooks() {
    hook_width = clip_width;
    hook_height = clip_height;
    hook_depth = clip_hook_depth;

    hook_z = -(clip_recess_z_from_top + clip_height);

    for (cx = [clip_center_x1, clip_center_x2]) {
        x_pos = cx - hook_width / 2;

        // Left lip hooks — face outward toward Y=0
        translate([x_pos, wall_thickness - hook_depth, hook_z])
            cube([hook_width, hook_depth, hook_height]);

        // Right lip hooks — face outward toward Y=max
        translate([x_pos, outer_width - wall_thickness, hook_z])
            cube([hook_width, hook_depth, hook_height]);
    }
}

// ============================================
// VENTILATION GRILLE (TOP)
// ============================================
module ventilation_grille() {
    // Centered on lid plate
    grille_x = (outer_length - vent_length) / 2;
    grille_y = (outer_width - vent_width) / 2;

    for (i = [0 : num_slots - 1]) {
        slot_x = grille_x + vent_start_offset + i * (slot_width + bridge_width);
        translate([slot_x, grille_y, -1])
            cube([slot_width, vent_width, lid_thickness + 2]);
    }
}

// ============================================
// LID MODULE
// ============================================
module lid() {
    difference() {
        union() {
            // Lid plate
            cube([outer_length, outer_width, lid_thickness]);

            // Inner lip — left side (Y=0)
            translate([0, wall_thickness, -lid_lip_depth])
                cube([outer_length, lid_lip_thickness, lid_lip_depth]);

            // Inner lip — right side (Y=max)
            translate([0, outer_width - wall_thickness - lid_lip_thickness, -lid_lip_depth])
                cube([outer_length, lid_lip_thickness, lid_lip_depth]);

            // Clip hooks on inner lips
            lid_clip_hooks();
        }
        // Ventilation cutouts
        ventilation_grille();
    }
}

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

// ============================================
// ASSEMBLY PREVIEW
// ============================================
module assembly() {
    tray();

    // Lid on top of tray
    translate([0, 0, wall_thickness + tray_height])
        lid();
}

// ============================================
// RENDER MODE
// ============================================
// Uncomment ONE of the following:

print_layout();    // For 3D printing (default)
// assembly();     // For visual assembly check
// tray();         // Tray only
// lid();          // Lid only
