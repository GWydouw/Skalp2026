#ifndef SKALP_CONVERT_H
#define SKALP_CONVERT_H

#include <stdio.h>
#include <vector>
#include <string>
#include <stdlib.h>

#include <SketchUpAPI/geometry.h>
#include <SketchUpAPI/transformation.h>
#include <SketchUpAPI/color.h>

struct point{
    double x;
    double y;
};

struct line{
    SUByte layer_index_R;
    SUByte layer_index_G;
    SUByte layer_index_B;
    point startpoint;
    point endpoint;
};

struct hiddenlines{
    long long index;
    point target_point;
    std::vector<line> lines;
};

int convert_integer(const std::string& s);
bool convert_boolean(const std::string& s);
double convert_double(const std::string& s) ;
std::vector<std::string> convert_string_array(const std::string& s);
std::vector<int> convert_integer_array(const std::string& s);
std::vector<bool> convert_boolean_array(const std::string& s);
std::vector<double> convert_double_array(const std::string& s) ;
std::vector<SUPoint3D> convert_point3D_array(const std::string& s);
std::vector<SUVector3D> convert_vector_array(const std::string& s);
std::vector<SUTransformation> convert_transformation_array(const std::string& s);
std::string point_to_string(point p);
std::string line_to_string(line l);
SUVector3D convert_vector(const std::string& s) ;
SUPoint3D convert_point3D(const std::string& s) ;
SUTransformation convert_transformation(const std::string& s) ;

#endif
