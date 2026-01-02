#include "sketchup.h"
#include <cmath>
#include <iostream>
#include <stdio.h>
#include <vector>

// --- Geometry Helpers ---

bool equal_points(LOPoint2D pt1, LOPoint2D pt2) {
  return (pt1.x == pt2.x) && (pt1.y == pt2.y);
}

double angle_3_points(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB) {
  double ba_x = ptB.x - ptA.x;
  double ba_y = ptB.y - ptA.y;
  double ca_x = ptC.x - ptA.x;
  double ca_y = ptC.y - ptA.y;
  double dot = ba_x * ca_x + ba_y * ca_y;
  double pcross = ba_x * ca_y - ba_y * ca_x;
  return atan2(pcross, dot);
}

bool smooth(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB) {
  if (equal_points(ptC, ptA) || equal_points(ptB, ptA) ||
      equal_points(ptC, ptB)) {
    return false;
  }
  double angle = angle_3_points(ptC, ptA, ptB);
  if (std::abs(angle) > 2.8) {
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

  result = SUAttributeDictionaryGetValue(attribute, "ID", &value);
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

    if (value_type == SUTypedValueType_String) {
      SUStringRef value_string = SU_INVALID;
      SUStringCreate(&value_string);
      if (SUTypedValueGetString(value, &value_string) == SU_ERROR_NONE) {
        attribute_value = su_string_to_std_string(value_string);
      }
      SUStringRelease(&value_string);
    } else if (value_type == SUTypedValueType_Bool) {
      bool b;
      if (SUTypedValueGetBool(value, &b) == SU_ERROR_NONE) {
        attribute_value = b ? "true" : "false";
      }
    } else if (value_type == SUTypedValueType_Int32) {
      int32_t i;
      if (SUTypedValueGetInt32(value, &i) == SU_ERROR_NONE) {
        attribute_value = std::to_string(i);
      }
    } else if (value_type == SUTypedValueType_Double) {
      double d;
      if (SUTypedValueGetDouble(value, &d) == SU_ERROR_NONE) {
        attribute_value = std::to_string(d);
      }
    }
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
  color.alpha = 255;
  color.red = (SUByte)red;
  color.green = (SUByte)green;
  color.blue = (SUByte)blue;
  SUMaterialSetColor(new_material, &color);
  SUMaterialSetName(new_material, name);
  SUMaterialSetOpacity(new_material, opacity);
  return new_material;
}
