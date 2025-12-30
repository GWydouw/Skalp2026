#ifndef SKALP_CONVERT_H
#define SKALP_CONVERT_H

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>

#include <SketchUpAPI/color.h>
#include <SketchUpAPI/geometry.h>
#include <SketchUpAPI/transformation.h>

// Simple 2D Point structure
struct point {
  double x;
  double y;
};

// Line structure containing start/end points and layer RGB indices for color
// mapping
struct line {
  SUByte layer_index_R;
  SUByte layer_index_G;
  SUByte layer_index_B;
  point startpoint;
  point endpoint;
};

// HiddenLines structure representing a processed entity (index) and its lines
struct hiddenlines {
  long long index;
  point target_point;
  std::vector<line> lines;
};

// --- Conversion Utilities ---

/**
 * Converts a string to an integer.
 */
int convert_integer(const std::string &s);

/**
 * Converts "true" to bool true, anything else to false.
 */
bool convert_boolean(const std::string &s);

/**
 * Converts a string to a double.
 */
double convert_double(const std::string &s);

// --- Array Converters ---
// These functions usually expect a delimiter (e.g., '|') separated string.

std::vector<std::string> convert_string_array(const std::string &s);
std::vector<int> convert_integer_array(const std::string &s);
std::vector<bool> convert_boolean_array(const std::string &s);
std::vector<double> convert_double_array(const std::string &s);

// --- SketchUp Type Converters ---

SUVector3D convert_vector(const std::string &s);
SUPoint3D convert_point3D(const std::string &s);
SUTransformation convert_transformation(const std::string &s);

std::vector<SUPoint3D> convert_point3D_array(const std::string &s);
std::vector<SUVector3D> convert_vector_array(const std::string &s);
std::vector<SUTransformation>
convert_transformation_array(const std::string &s);

// --- Formatters ---

std::string point_to_string(point p);
std::string line_to_string(line l);

#endif // SKALP_CONVERT_H
