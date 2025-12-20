
#include "sketchup.h"
#include <stdio.h>
#include <iostream>

bool equal_points(LOPoint2D pt1, LOPoint2D pt2){
    if ((pt1.x == pt2.x) && (pt1.y == pt2.y)){
        return true;
    }else{
        return false;
    }
}

//angle_3_points: java reference implementation  http://stackoverflow.com/questions/3057448/angle-between-3-vertices
//returns signed angle BAC in radians [PI..-PI], depending on whether BAC goes clockwise or counterclockwise
double angle_3_points(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB){
    double ba_x = ptB.x - ptA.x;
    double ba_y = ptB.y - ptA.y;
    
    double ca_x = ptC.x - ptA.x;
    double ca_y = ptC.y - ptA.y;
    
    double dot =    ba_x * ca_x + ba_y * ca_y;
    double pcross = ba_x * ca_y - ba_y * ca_x;
    
    double angle = atan2(pcross, dot);
    
    return angle;
}

bool smooth(LOPoint2D ptC, LOPoint2D ptA, LOPoint2D ptB){
    
    if (equal_points(ptC, ptA) || equal_points(ptB, ptA) || equal_points(ptC, ptB)){
        return false;
    }
    
    double angle = angle_3_points(ptC, ptA, ptB);
    
    if (std::abs(angle) > 2.8){ //radians
        return true;
    }else{
        return false;
    };
}

bool is_skalp_group(SUGroupRef group){
    SUResult result;
    SUEntityRef entity = SU_INVALID;
    entity = SUGroupToEntity(group);
    
    SUAttributeDictionaryRef attribute = SU_INVALID;
    result = SUEntityGetAttributeDictionary(entity, "Skalp", &attribute);
    
    if (result != SU_ERROR_NONE){
        return false;
    };
    
    SUTypedValueRef value = SU_INVALID;
    result = SUTypedValueCreate(&value);
    
    if (result != SU_ERROR_NONE){
        return false;
    };
    
    result = SUAttributeDictionaryGetValue(attribute, "ID", &value);
    
    if (result == SU_ERROR_NONE){
        return true;
    }else{
        return false;
    }
};

char* suStringRef_to_cString(SUStringRef string1){
    size_t stringlength1 = 0;
    size_t count;
    
    SUStringGetUTF8Length(string1, &stringlength1);
    char* c_string1 = new char[stringlength1 + 1];
    SUStringGetUTF8(string1, stringlength1 + 1, c_string1, &count);
    
    return c_string1;
}

std::string suStringRef_to_String(SUStringRef string1){
    size_t stringlength1 = 0;
    size_t count;
    
    SUStringGetUTF8Length(string1, &stringlength1);
    char* c_string1 = new char[stringlength1 + 1];
    SUStringGetUTF8(string1, stringlength1 + 1, c_string1, &count);
    
    std::string str(c_string1, strnlen(c_string1, 50));
    return str;
}

bool suStringRef_equal(SUStringRef string1 , SUStringRef string2){
    
    size_t stringlength1 = 0;
    size_t stringlength2 = 0;
    size_t count;
    
    SUStringGetUTF8Length(string1, &stringlength1);
    char* c_string1 = new char[stringlength1 + 1];
    SUStringGetUTF8(string1, stringlength1 + 1, c_string1, &count);
    
    SUStringGetUTF8Length(string2, &stringlength2);
    char* c_string2 = new char[stringlength2 + 1];
    SUStringGetUTF8(string2, stringlength2 + 1, c_string1, &count);
    
    if (strcmp(c_string1, c_string2)==0){
        delete []c_string1;
        delete []c_string2;
        return true;
    }else{
        delete []c_string1;
        delete []c_string2;
        return false;
    }
}

std::string get_attribute(SUEntityRef entity, std::string dict_name, std::string key){
    SUResult result;
    std::string attribute_value;
    
    SUAttributeDictionaryRef attribute = SU_INVALID;
    result = SUEntityGetAttributeDictionary(entity, dict_name.c_str(), &attribute);
    
    if (result != SU_ERROR_NONE){
        return "";
    };
    
    SUTypedValueRef value = SU_INVALID;
    result = SUTypedValueCreate(&value);
    
    if (result != SU_ERROR_NONE){
        return "";
    };
    
    result = SUAttributeDictionaryGetValue(attribute, key.c_str(), &value);
    
    if (result == SU_ERROR_NONE){
        SUTypedValueType value_type;
        SUTypedValueGetType(value, &value_type);
        
        SUStringRef value_string = SU_INVALID;
        SUStringCreate(&value_string);
        
        result = SUTypedValueGetString(value, &value_string);
        
        if (result != SU_ERROR_NONE){
            return "";
        };
        
        attribute_value = suStringRef_to_String(value_string);
        
        SUStringRelease(&value_string);
        
    }else{
        return "";
    };
    SUTypedValueRelease(&value);
    return attribute_value;
}

SUMaterialRef create_color_material(const char* name, double opacity, int red, int green, int blue){
    SUMaterialRef new_material = SU_INVALID;
    SUMaterialCreate(&new_material);
    
    SUColor color;
    
    color.alpha = 100;
    color.red = red;
    color.green = green;
    color.blue = blue;
    
    SUMaterialSetColor(new_material, &color);
    SUMaterialSetName(new_material, name);
    SUMaterialSetOpacity(new_material, opacity);
    
    return new_material;
};
