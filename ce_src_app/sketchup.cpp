#include "sketchup.h"
#include <cmath>
#include <iostream>
#include <stdio.h>
#include <vector>

// --- Geometry Helpers ---

bool equal_points(LOPoint2D pt1, LOPoint2D pt2) {
  // Use an epsilon for float comparison? Assuming exact equality required here.
  return (pt1.x == pt2.x) && (pt1.y == pt2.y);
}

// angle_3_points: java reference implementation
// http://stackoverflow.com/questions/3057448/angle-between-3-vertices returns
// signed angle BAC in radians [PI..-PI], depending on whether BAC goes
// clockwise or counterclockwise
double angle_3_points(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB) {
  double ba_x = ptB.x - ptA.x;
  double ba_y = ptB.y - ptA.y;

  double ca_x = ptC.x - ptA.x;
  double ca_y = ptC.y - ptA.y;

  double dot = ba_x * ca_x + ba_y * ca_y;
  double pcross = ba_x * ca_y - ba_y * ca_x;

  double angle = atan2(pcross, dot);

  return angle;
}

bool smooth(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB) {
  if (equal_points(ptC, ptA) || equal_points(ptB, ptA) ||
      equal_points(ptC, ptB)) {
    return false;
  }

  double angle = angle_3_points(ptC, ptA, ptB);

  // Check if angle is large enough to be considered "smooth" (approx > 160
  // degrees)
  if (std::abs(angle) > 2.8) { // 2.8 radians is approx 160 degrees
    return true;
  }
  return false;
}

// --- Entity Helpers ---

bool is_skalp_group(SUGroupRef group) {
  SUResult result;
  SUEntityRef entity = SUGroupToEntity(group);
  if (SUIsInvalid(entity))
    return false;

  SUAttributeDictionaryRef attribute = SU_INVALID;
  result = SUEntityGetAttributeDictionary(entity, "Skalp", &attribute);

  if (result != SU_ERROR_NONE || SUIsInvalid(attribute)) {
    return false;
  }

  SUTypedValueRef value = SU_INVALID;
  result = SUTypedValueCreate(&value);

  if (result != SU_ERROR_NONE) {
    return false;
  }

  // Check for "ID" key
  result = SUAttributeDictionaryGetValue(attribute, "ID", &value);

  // We must release the TypedValue regardless of result
  SUTypedValueRelease(&value);

  if (result == SU_ERROR_NONE) {
    return true;
  }
  return false;
}

// --- String Helpers ---

std::string su_string_to_std_string(SUStringRef string_ref) {
  if (SUIsInvalid(string_ref))
    return "";

  size_t length = 0;
  SUStringGetUTF8Length(string_ref, &length);
  if (length == 0)
    return "";

  std::vector<char> buffer(length + 1);
  size_t returned_count = 0;
  SUStringGetUTF8(string_ref, length + 1, buffer.data(), &returned_count);

  return std::string(buffer.data());
}

bool su_string_equal(SUStringRef string1, SUStringRef string2) {
  std::string s1 = su_string_to_std_string(string1);
  std::string s2 = su_string_to_std_string(string2);
  return (s1 == s2);
}

// --- Attribute Helpers ---

std::string get_attribute(SUEntityRef entity, std::string dict_name,
                          std::string key) {
  SUResult result;
  std::string attribute_value = "";

  SUAttributeDictionaryRef attribute = SU_INVALID;
  result =
      SUEntityGetAttributeDictionary(entity, dict_name.c_str(), &attribute);

  if (result != SU_ERROR_NONE || SUIsInvalid(attribute)) {
    return "";
  }

  SUTypedValueRef value = SU_INVALID;
  result = SUTypedValueCreate(&value);
  if (result != SU_ERROR_NONE)
    return "";

  result = SUAttributeDictionaryGetValue(attribute, key.c_str(), &value);

  if (result == SU_ERROR_NONE) {
    SUTypedValueType value_type;
    SUTypedValueGetType(value, &value_type);

    // We only handle parsing if it's a string, assuming caller expects a string
    // representation If the attribute is int/double, SUTypedValueGetString
    // might fail or behave specific way? Actually SUTypedValueGetString only
    // works if type is String. Skalp attributes seem to be strings.

    SUStringRef value_string = SU_INVALID;
    SUStringCreate(&value_string);

    if (SUTypedValueGetString(value, &value_string) == SU_ERROR_NONE) {
      attribute_value = su_string_to_std_string(value_string);
    }

    SUStringRelease(&value_string);
  }

  SUTypedValueRelease(&value);
  return attribute_value;
}

// --- Material Helpers ---

SUMaterialRef create_color_material(const char *name, double opacity, int red,
                                    int green, int blue) {
  SUMaterialRef new_material = SU_INVALID;
  SUMaterialCreate(&new_material);

  SUColor color;
  color.alpha =
      255; // API struct often ignores alpha in Color struct for Materials?
  // Wait, Setup says color.alpha = 100 in original? SUColor alpha is usually
  // byte 0-255? or unused? In SketchUp C API, Material Opacity is separate.
  // Original code: color.alpha = 100;

  color.red = (SUByte)red;
  color.green = (SUByte)green;
  color.blue = (SUByte)blue;

  SUMaterialSetColor(new_material, &color);
  SUMaterialSetName(new_material, name);
  SUMaterialSetOpacity(new_material, opacity);

  return new_material;
}
