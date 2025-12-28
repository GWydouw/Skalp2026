#ifndef SKETCHUP_H
#define SKETCHUP_H

#include <stdio.h>
#include <vector>
#include <string>
#include <math.h>
#include <cmath>

#include <LayOutAPI/layout.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/common.h>
#include <SketchUpAPI/geometry.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/entity.h>
#include <SketchUpAPI/model/typed_value.h>


extern std::string error_string;
bool equal_points(LOPoint2D pt1, LOPoint2D pt2);
bool smooth(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB);
bool is_skalp_group(SUGroupRef group);
bool suStringRef_equal(SUStringRef string1 , SUStringRef string2);
double angle_3_points(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB);
char* suStringRef_to_cString(SUStringRef string1);
std::string suStringRef_to_String(SUStringRef string1);
std::string get_attribute(SUEntityRef entity, std::string dict_name, std::string key);
SUMaterialRef create_color_material(const char* name, double opacity, int red, int green, int blue);

#endif 
