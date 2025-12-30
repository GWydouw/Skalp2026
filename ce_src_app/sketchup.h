#ifndef SKETCHUP_H
#define SKETCHUP_H

#include <cmath>
#include <stdio.h>
#include <string>
#include <vector>

// SketchUp / LayOut API headers
#include <LayOutAPI/layout.h>
#include <SketchUpAPI/common.h>
#include <SketchUpAPI/geometry.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/entity.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/typed_value.h>

// Global error string
extern std::string error_string;

// --- Geometry Helpers ---
bool equal_points(LOPoint2D pt1, LOPoint2D pt2);
bool smooth(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB);
double angle_3_points(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB);

// --- Entity/Group Helpers ---
bool is_skalp_group(SUGroupRef group);
std::string get_attribute(SUEntityRef entity, std::string dict_name,
                          std::string key);

// --- String Helpers ---
/**
 * Converts a SketchUp StringRef to a C++ std::string.
 * Handles UTF-8 conversion and memory management.
 */
std::string su_string_to_std_string(SUStringRef string_ref);

/**
 * Compares two SketchUp StringRefs for equality.
 */
bool su_string_equal(SUStringRef string1, SUStringRef string2);

// Legacy C-string helper (deprecated, replaced by su_string_to_std_string)
// char* suStringRef_to_cString(SUStringRef string1);

// --- Material Helpers ---
SUMaterialRef create_color_material(const char *name, double opacity, int red,
                                    int green, int blue);

#endif // SKETCHUP_H
