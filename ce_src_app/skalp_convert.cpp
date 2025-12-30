#include "skalp_convert.h"
#include <algorithm>
#include <iostream>

// --- Helper Functions ---

/**
 * Splits a string by a delimiter.
 *
 * @param s: The input string.
 * @param delim: The delimiter string.
 * @return A vector of substrings.
 */
std::vector<std::string> split_string(const std::string &s,
                                      const std::string &delim) {
  std::vector<std::string> result;
  if (s.empty())
    return result;

  std::string::const_iterator substart = s.begin(), subend;

  while (true) {
    subend = std::search(substart, s.end(), delim.begin(), delim.end());
    std::string temp(substart, subend);

    // Original code only pushed if !temp.empty().
    // We preserve this behavior to avoid empty strings from consecutive
    // delimiters.
    if (!temp.empty()) {
      result.push_back(temp);
    }

    if (subend == s.end()) {
      break;
    }
    substart = subend + delim.size();
  }
  return result;
}

// --- Formatters ---

std::string point_to_string(point p) {
  return "[" + std::to_string(static_cast<long double>(p.x)) + "," +
         std::to_string(static_cast<long double>(p.y)) + "]";
}

std::string line_to_string(line l) {
  return "[" + point_to_string(l.startpoint) + "," +
         point_to_string(l.endpoint) + "]";
}

// --- Basic Converters ---

int convert_integer(const std::string &s) { return atoi(s.c_str()); }

double convert_double(const std::string &s) { return atof(s.c_str()); }

bool convert_boolean(const std::string &s) { return (s == "true"); }

// --- Array Converters ---
// Most arrays are |-delimited.

std::vector<std::string> convert_string_array(const std::string &s) {
  return split_string(s, "|");
}

std::vector<int> convert_integer_array(const std::string &s) {
  std::vector<std::string> tokens = split_string(s, "|");
  std::vector<int> result;
  result.reserve(tokens.size());
  for (const auto &token : tokens) {
    result.push_back(convert_integer(token));
  }
  return result;
}

std::vector<bool> convert_boolean_array(const std::string &s) {
  std::vector<std::string> tokens = split_string(s, "|");
  std::vector<bool> result;
  result.reserve(tokens.size());
  for (const auto &token : tokens) {
    result.push_back(convert_boolean(token));
  }
  return result;
}

std::vector<double> convert_double_array(const std::string &s) {
  std::vector<std::string> tokens = split_string(s, "|");
  std::vector<double> result;
  result.reserve(tokens.size());
  for (const auto &token : tokens) {
    result.push_back(convert_double(token));
  }
  return result;
}

// --- SketchUp Type Converters ---

SUPoint3D convert_point3D(const std::string &s) {
  // Points are comma-separated: "x,y,z"
  std::vector<std::string> tokens = split_string(s, ",");

  SUPoint3D point = {0, 0, 0};
  if (tokens.size() >= 3) {
    point.x = convert_double(tokens[0]);
    point.y = convert_double(tokens[1]);
    point.z = convert_double(tokens[2]);
  }
  return point;
}

SUVector3D convert_vector(const std::string &s) {
  // Vectors are comma-separated: "x,y,z"
  std::vector<std::string> tokens = split_string(s, ",");

  SUVector3D vector = {0, 0, 0};
  if (tokens.size() >= 3) {
    vector.x = convert_double(tokens[0]);
    vector.y = convert_double(tokens[1]);
    vector.z = convert_double(tokens[2]);
  }
  return vector;
}

SUTransformation convert_transformation(const std::string &s) {
  // Transformations are comma-separated 16 doubles
  std::vector<std::string> tokens = split_string(s, ",");

  // Initialize identity matrix or zero? Original code implied simple mapping.
  // SUTransformation struct has `values[16]` usually, but here struct init is
  // used. Assuming standard struct layout. BUT SketchUpAPI/transformation.h
  // struct SUTransformation { double values[16]; }; Original code used named
  // elements or array access? Original code: ruby_array[0]...ruby_array[15].

  // Let's safe guard size.
  double val[16] = {0};
  for (size_t i = 0; i < 16 && i < tokens.size(); ++i) {
    val[i] = convert_double(tokens[i]);
  }

  SUTransformation transformation;
  // SUTransformation is often `typedef struct { double values[16]; }
  // SUTransformation;` Assigning to values directly if accessible, or using
  // brace init if simple struct. Original code used braces: { val[0], val[1]
  // ... }

  // We will use brace initialization compatible with C struct.
  transformation = {val[0],  val[1],  val[2],  val[3], val[4],  val[5],
                    val[6],  val[7],  val[8],  val[9], val[10], val[11],
                    val[12], val[13], val[14], val[15]};

  return transformation;
}

// --- Array of SketchUp Types ---

std::vector<SUPoint3D> convert_point3D_array(const std::string &s) {
  std::vector<std::string> tokens = split_string(s, "|");
  std::vector<SUPoint3D> result;
  result.reserve(tokens.size());
  for (const auto &token : tokens) {
    result.push_back(convert_point3D(token));
  }
  return result;
}

std::vector<SUVector3D> convert_vector_array(const std::string &s) {
  std::vector<std::string> tokens = split_string(s, "|");
  std::vector<SUVector3D> result;
  result.reserve(tokens.size());
  for (const auto &token : tokens) {
    result.push_back(convert_vector(token));
  }
  return result;
}

std::vector<SUTransformation>
convert_transformation_array(const std::string &s) {
  std::vector<std::string> tokens = split_string(s, "|");
  std::vector<SUTransformation> result;
  result.reserve(tokens.size());
  for (const auto &token : tokens) {
    result.push_back(convert_transformation(token));
  }
  return result;
}
