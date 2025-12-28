#include <stdio.h>
#include <iostream>
#include <string>
#include <vector>

#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/texture.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/entity.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/camera.h>
#include <SketchUpAPI/model/typed_value.h>
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/section_plane.h>
#include <SketchUpAPI/geometry.h>

#include "sketchup.h"

bool remove_materials(SUModelRef model){
    SUResult result;
    
    size_t num_materials;
    size_t count;
    
    SUModelGetNumMaterials(model, &num_materials);
    std::vector<SUMaterialRef> materials(num_materials);
    
    for (size_t i = 0; i < num_materials; ++i) {
        SUSetInvalid(materials[i]);
    }
    
    SUModelGetMaterials(model, num_materials, &materials[0], &count);
    
    for (size_t i = 0; i < num_materials; ++i) {
        SUTextureRef texture = SU_INVALID;
        result = SUMaterialGetTexture(materials[i], &texture);
        
        if (result == SU_ERROR_NONE){
            SUMaterialSetType(materials[i], SUMaterialType_Colored);
        };
    }
    
    materials.clear();
    return true;
};

SUEntitiesRef get_sectiongroups(SUEntitiesRef entities){
    std::cout << "get_sectiongroups";
    SUEntitiesRef section_group_entities = SU_INVALID;
    
    SUResult result;
    size_t num_groups;
    size_t count;
    
    SUEntitiesGetNumGroups(entities, &num_groups);
    std::vector<SUGroupRef> groups(num_groups);
    
    for (size_t i = 0; i < num_groups; ++i) {
        SUSetInvalid(groups[i]);
    }
    
    result = SUEntitiesGetGroups(entities, num_groups, &groups[0], &count);
    
    for (size_t i = 0; i < num_groups; i++){
        
        SUStringRef group_name = SU_INVALID;
        SUStringCreate(&group_name);
        result = SUGroupGetName(groups[i], &group_name);
        /*
         if (result == SU_ERROR_NONE){
         std::cout << "SUGroupGetName result: success";
         }else if (result == SU_ERROR_INVALID_INPUT){
         std::cout << "SUGroupGetName result: group is not a valid object";
         }else if (result == SU_ERROR_NULL_POINTER_OUTPUT){
         std::cout << "SUGroupGetName result: name is NULL";
         }else if (result == SU_ERROR_INVALID_OUTPUT){
         std::cout << "SUGroupGetName result: name does not point to a valid SUStringRef object";
         }else {
         std::cout << "SUGroupGetName result: ELSE " << result;
         }
         */
        
        if (strcmp(suStringRef_to_cString(group_name), "Skalp sections")==0){
            SUGroupGetEntities(groups[i], &section_group_entities);
            SUStringRelease(&group_name);
            return section_group_entities;
        }
        SUStringRelease(&group_name);
    }
    
    
    return section_group_entities;
}

bool move_section_group(SUEntitiesRef entities, std::string ruby_id, SUTransformation transformation){
    
    SUResult result;
    size_t num_groups;
    size_t count;
    
    SUEntitiesGetNumGroups(entities, &num_groups);
    std::vector<SUGroupRef> groups(num_groups);
    
    for (size_t i = 0; i < num_groups; ++i) {
        SUSetInvalid(groups[i]);
    }
    
    result = SUEntitiesGetGroups(entities, num_groups, &groups[0], &count);
    
    for (size_t i = 0; i < num_groups; i++){
        
        SUEntityRef entity = SU_INVALID;
        entity = SUGroupToEntity(groups[i]);
        
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
            SUTypedValueType value_type;
            SUTypedValueGetType(value, &value_type);
            
            SUStringRef value_string = SU_INVALID;
            SUStringCreate(&value_string);
            
            result = SUTypedValueGetString(value, &value_string);
            
            if (result != SU_ERROR_NONE){
                return false;
            };
            
            size_t value_length = 0;
            
            result = SUStringGetUTF8Length(value_string, &value_length);
            
            if (result != SU_ERROR_NONE){
                return false;
            };
            
            char* value_c_string = new char[value_length + 1];
            
            SUStringGetUTF8(value_string, value_length + 1, value_c_string, &count);
            if (strcmp(ruby_id.c_str(),value_c_string)==0){
                result = SUGroupSetTransform(groups[i], &transformation);
                
                if (result != SU_ERROR_NONE){
                    return false;
                };
            }
            SUStringRelease(&value_string);
            delete []value_c_string;
        }else{
            std::cout << "error";
        };
        SUTypedValueRelease(&value);
    };
    return true;
}

bool setup_reversed_scene(std::string path, std::string new_path, std::vector<int> page_index_array,  std::vector<SUPoint3D> eye_array, std::vector<SUPoint3D> target_array, std::vector<SUTransformation> transformation_array, std::vector<std::string> id_array, std::vector<SUVector3D> up_vector_array,  double  bounds){
    
    // Always initialize the API before using it
    SUInitialize();
    
    // Load the model from a file
    SUModelRef model = SU_INVALID;
    
    // Load the SketchUp model.
    SUModelLoadStatus status;
    SUResult result = SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);
    
    // It's best to always check the return code from each SU function call.
    // Only showing this check once to keep this example short.
    if (result != SU_ERROR_NONE){
        return false;
    };
    
    SUEntitiesRef entities = SU_INVALID;
    result = SUModelGetEntities(model, &entities);
    
    if (result != SU_ERROR_NONE){
        SUModelRelease(&model);
        return false;
    };
    
    //**************************
    //reverse sectionplanes
    //**************************
    
    size_t num_sectionplanes;
    size_t count;
    
    SUEntitiesGetNumSectionPlanes(entities, &num_sectionplanes);
    std::vector<SUSectionPlaneRef> sectionplanes(num_sectionplanes);
    
    for (size_t i = 0; i < num_sectionplanes; ++i) {
        SUSetInvalid(sectionplanes[i]);
    }
    
    result = SUEntitiesGetSectionPlanes(entities, num_sectionplanes, &sectionplanes[0], &count);
    
    for (size_t i = 0; i < num_sectionplanes; i++){
        SUPlane3D plane = SU_INVALID;
        SUPlane3D newplane = SU_INVALID;
        SUSectionPlaneGetPlane(sectionplanes[i], &plane);
        newplane.a = -plane.a;
        newplane.b = -plane.b;
        newplane.c = -plane.c;
        newplane.d = -plane.d;
        SUSectionPlaneSetPlane(sectionplanes[i], &newplane);
    };
    
    //**************************
    // reverse scenes cameras
    //**************************
    
    // Get sectiongroup entities
    
    SUEntitiesRef section_group_entities = SU_INVALID;
    section_group_entities = get_sectiongroups(entities);
    
    if (SUIsInvalid(section_group_entities)){
        std::cout << "sectiongroup NOT found";
        return false;
    }else{

    };
    
    size_t i = page_index_array.size();
    
    for (size_t j = 0; j < i; ++j) {
        int page_index = page_index_array[j];
        
        SUPoint3D new_target = target_array[j];
        SUPoint3D new_eye = eye_array[j];
        SUVector3D new_up_vector = up_vector_array[j];
        
        move_section_group(section_group_entities, id_array[j], transformation_array[j]);
        
        size_t num_scenes;
        
        SUModelGetNumScenes(model, &num_scenes);
        std::vector<SUSceneRef> scenes(num_scenes);
        
        for (size_t i = 0; i < num_scenes; ++i) {
            SUSetInvalid(scenes[i]);
        }
        
        result = SUModelGetScenes(model, num_scenes, &scenes[0], &count);
        
        if (page_index != -1){
            
            scenes[page_index];
            
            SUCameraRef scene_cam = SU_INVALID;
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUModelGetScenes";
                return false;
            };
            
            result = SUSceneGetCamera(scenes[page_index], &scene_cam);
            
            SUPoint3D position;
            SUPoint3D target;
            SUVector3D up_vector;
            
            result = SUCameraGetOrientation(scene_cam, &position, &target, &up_vector);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUCameraGetOrientation 1";
                return false;
            };
            
            result = SUCameraSetOrientation(scene_cam, &new_eye, &new_target, &new_up_vector);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUCameraSetOrientation 1";
                return false;
            };
            
            SUCameraSetPerspective(scene_cam, false);
            SUCameraSetOrthographicFrustumHeight(scene_cam, bounds);
            result = SUSceneSetCamera(scenes[page_index], scene_cam);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUSceneSetCamera 1";
                return false;
            };
            
        }else{
            SUCameraRef scene_cam = SU_INVALID;
            
            result = SUModelGetCamera(model, &scene_cam);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUModelGetCamera";
                return false;
            };
            
            SUPoint3D position;
            SUPoint3D target;
            SUVector3D up_vector;
            
            result = SUCameraGetOrientation(scene_cam, &position, &target, &up_vector);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUCameraGetOrientation 2";
                return false;
            };
            
            result = SUCameraSetOrientation(scene_cam, &new_eye, &new_target, &new_up_vector);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUCameraSetOrientation 2";
                return false;
            };
            
            SUCameraSetPerspective(scene_cam, false);
            SUCameraSetOrthographicFrustumHeight(scene_cam, bounds);
            result = SUModelSetCamera(model, &scene_cam);
            
            if (result != SU_ERROR_NONE){
                SUModelRelease(&model);
                SUTerminate();
                error_string = "SUModelSetCamera 2";
                return false;
            };
        };
    };
    
    remove_materials(model);
    
    // Save the in-memory model to a file
    //SUModelSaveToFile(model, new_path.c_str());
    SUModelSaveToFileWithVersion(model, new_path.c_str(),SUModelVersion_Current);
    // Must release the model or there will be memory leaks
    SUModelRelease(&model);
    // Always terminate the API when done using it
    SUTerminate();
    return true;
};

