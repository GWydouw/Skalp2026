#include "skalp_convert.h"
#include <algorithm>

std::string point_to_string(point p){
    return "[" + std::to_string(static_cast<long double> (p.x)) + "," + std::to_string(static_cast<long double>(p.y)) + "]";
}

std::string line_to_string(line l){
    return "[" + point_to_string(l.startpoint) + "," + point_to_string(l.endpoint) + "]";
}

std::vector<std::string> convert_string_array(const std::string& s) {
    
    std::vector<std::string> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
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

int convert_integer(const std::string& s) {
    int value = atoi(s.c_str());
    return value;
}

std::vector<int> convert_integer_array(const std::string& s) {
    
    std::vector<int> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            result.push_back(convert_integer(temp));
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    return result;
}

bool convert_boolean(const std::string& s){
    bool result;
    
    if (s == "true"){
        result = true;
    }else{
        result = false;
    }
    return result;
}

std::vector<bool> convert_boolean_array(const std::string& s) {
    
    std::vector<bool> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            bool value = convert_boolean(temp); // atoi(temp.c_str());
            result.push_back(value);
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    return result;
}

double convert_double(const std::string& s) {
    double value = atof(s.c_str());
    return value;
}

std::vector<double> convert_double_array(const std::string& s) {
    
    std::vector<double> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            result.push_back(convert_double(temp));
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    return result;
}

SUTransformation convert_transformation(const std::string& s) {
    
    const std::string delim = ",";
    
    std::vector<double> ruby_array;
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            double value = atof(temp.c_str());
            ruby_array.push_back(value);
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    
    SUTransformation transformation =  { ruby_array[0],
        ruby_array[1],
        ruby_array[2],
        ruby_array[3],
        ruby_array[4],
        ruby_array[5],
        ruby_array[6],
        ruby_array[7],
        ruby_array[8],
        ruby_array[9],
        ruby_array[10],
        ruby_array[11],
        ruby_array[12],
        ruby_array[13],
        ruby_array[14],
        ruby_array[15]} ;
    
    return transformation;
}

SUPoint3D convert_point3D(const std::string& s) {
    
    const std::string delim = ",";
    
    std::vector<double> ruby_array;
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            double value = atof(temp.c_str());
            ruby_array.push_back(value);
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    
    SUPoint3D point = SU_INVALID;
    point.x =  ruby_array[0];
    point.y =  ruby_array[1];
    point.z =  ruby_array[2];
    
    return point;
}

std::vector<SUPoint3D> convert_point3D_array(const std::string& s){
    
    std::vector<SUPoint3D> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            result.push_back(convert_point3D(temp));
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    return result;
}

SUVector3D convert_vector(const std::string& s) {
    
    const std::string delim = ",";
    
    std::vector<double> ruby_array;
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            double value = atof(temp.c_str());
            ruby_array.push_back(value);
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    
    SUVector3D vector = SU_INVALID;
    vector.x =  ruby_array[0];
    vector.y =  ruby_array[1];
    vector.z =  ruby_array[2];
    
    return vector;
}

std::vector<SUVector3D> convert_vector_array(const std::string& s){
    
    std::vector<SUVector3D> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            result.push_back(convert_vector(temp));
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    return result;
}

std::vector<SUTransformation> convert_transformation_array(const std::string& s){
    
    std::vector<SUTransformation> result;
    const std::string delim = "|";
    std::string::const_iterator substart = s.begin(), subend;
    
    while (true) {
        subend = search(substart, s.end(), delim.begin(), delim.end());
        std::string temp(substart, subend);
        if (!temp.empty()) {
            result.push_back(convert_transformation(temp));
        }
        if (subend == s.end()) {
            break;
        }
        substart = subend + delim.size();
    }
    return result;
}

