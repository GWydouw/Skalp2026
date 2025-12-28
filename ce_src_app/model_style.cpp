#include <stdio.h>
#include <iostream>
#include <string>
#include <vector>

#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/entity.h>
#include <SketchUpAPI/model/face.h>
#include <SketchUpAPI/model/component_definition.h>
#include <SketchUpAPI/model/component_instance.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/typed_value.h>
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/geometry.h>

#include "skalp_convert.h"
#include "sketchup.h"

SUMaterialRef get_white_transparent_material(SUModelRef model, double opacity){
    size_t num_materials;
    size_t count;
    
    SUModelGetNumMaterials(model, &num_materials);
    std::vector<SUMaterialRef> materials(num_materials);
    
    for (size_t i = 0; i < num_materials; ++i) {
        SUSetInvalid(materials[i]);
    }
    
    SUModelGetMaterials(model, num_materials, &materials[0], &count);
    
    std::string transparence_name;
    int opacity_int = int(opacity * 10);
    
    switch (opacity_int){
        case 1:
            transparence_name = "Skalp White 10%";
            opacity = 0.1;
            break;
        case 2:
            transparence_name = "Skalp White 20%";
            opacity = 0.2;
            break;
        case 3:
            transparence_name = "Skalp White 30%";
            opacity = 0.3;
            break;
        case 4:
            transparence_name = "Skalp White 40%";
            opacity = 0.4;
            break;
        case 5:
            transparence_name = "Skalp White 50%";
            opacity = 0.5;
            break;
        case 6:
            transparence_name = "Skalp White 60%";
            opacity = 0.6;
            break;
        case 7:
            transparence_name = "Skalp White 70%";
            opacity = 0.7;
            break;
        case 8:
            transparence_name = "Skalp White 80%";
            opacity = 0.8;
            break;
        case 9:
            transparence_name = "Skalp White 90%";
            opacity = 0.9;
            break;
        default:
            transparence_name = "Skalp White";
            opacity = 1.0;
    }
    
    for (size_t i = 0; i < num_materials; ++i){
        SUStringRef material_name = SU_INVALID;
        SUMaterialGetName(materials[i], &material_name);
        
        if (strcmp(suStringRef_to_cString(material_name), transparence_name.c_str())){
            return materials[i];
        }
    }
    return create_color_material(transparence_name.c_str(), opacity, 255, 255, 255);
}

void process_all_entities(SUModelRef model, SUEntitiesRef entities, SUMaterialRef white_material, std::string parent_fase, std::string fase, SUMaterialRef color_material){
    
    SUResult result;
    size_t num_faces;
    size_t count;
    
    
    SUEntitiesGetNumFaces(entities, &num_faces);
    std::vector<SUFaceRef> faces(num_faces);
    
    for (size_t i = 0; i < num_faces; ++i) {
        SUSetInvalid(faces[i]);
    }
    
    result = SUEntitiesGetFaces(entities, num_faces, &faces[0], &count);
    
    for (size_t i = 0; i < num_faces; i++){
        SUMaterialRef old_material = SU_INVALID;
        SUFaceGetFrontMaterial(faces[i], &old_material);
        
        double opacity;
        SUMaterialGetOpacity(old_material, &opacity);
        
        if (opacity < 1.0 && SUIsValid(old_material)){
            SUMaterialRef white_material_transparent = get_white_transparent_material(model, opacity);
            SUFaceSetBackMaterial(faces[i], white_material_transparent);
            SUFaceSetFrontMaterial(faces[i], white_material_transparent);
        } else {
            SUFaceSetBackMaterial(faces[i], white_material);
            SUFaceSetFrontMaterial(faces[i], white_material);
        }
        
        std::string entity_fase = get_attribute(SUFaceToEntity(faces[i]), "DWM", "fase");
        
        if ((entity_fase == fase && entity_fase != "") || (entity_fase == "" && parent_fase != "" && parent_fase == fase)) {
            SUFaceSetBackMaterial(faces[i], color_material);
            SUFaceSetFrontMaterial(faces[i], color_material);
        }        
    };
    
    //if component do process_all_entities
    size_t num_instances;
    
    SUEntitiesGetNumInstances(entities, &num_instances);
    std::vector<SUComponentInstanceRef> instances(num_instances);
    
    for (size_t i = 0; i < num_instances; ++i) {
        SUSetInvalid(instances[i]);
    }
    
    result = SUEntitiesGetInstances(entities, num_instances, &instances[0], &count);
    
    for (size_t i = 0; i < num_instances; i++){
        SUComponentDefinitionRef component_def = SU_INVALID;
        
        SUComponentInstanceGetDefinition(instances[i], &component_def);
        
        SUEntitiesRef component_entities = SU_INVALID;
        result = SUComponentDefinitionGetEntities(component_def, &component_entities);
        
        if (result == SU_ERROR_NONE){
            std::string entity_fase = get_attribute(SUComponentInstanceToEntity(instances[i]), "DWM", "fase");
            if (entity_fase != ""){
                parent_fase = entity_fase;
            }
            process_all_entities(model, component_entities, white_material, parent_fase, fase, color_material);
        }
    }
    
    //if group do process_all_entities
    size_t num_groups;
    
    SUEntitiesGetNumGroups(entities, &num_groups);
    std::vector<SUGroupRef> groups(num_groups);
    
    for (size_t i = 0; i < num_groups; ++i) {
        SUSetInvalid(groups[i]);
    }
    
    result = SUEntitiesGetGroups(entities, num_groups, &groups[0], &count);
    
    for (size_t i = 0; i < num_groups; i++){
        SUEntitiesRef group_entities = SU_INVALID;
        result = SUGroupGetEntities(groups[i], &group_entities);
        
        if (result == SU_ERROR_NONE){
            if (!is_skalp_group(groups[i])) {
                std::string entity_fase = get_attribute(SUGroupToEntity(groups[i]), "DWM", "fase");
                if (entity_fase != ""){
                    parent_fase = entity_fase;
                }
                process_all_entities(model, group_entities, white_material, parent_fase, fase, color_material);
            }
        }
    }
    return;
};

bool create_white_model(std::string path, std::string fase, SUMaterialRef color_material){
    static std::string file_path;
    
    // Always initialize the API before using it
    SUInitialize();
    
    // Load the model from a file
    SUModelRef model = SU_INVALID;
    
    size_t path_end = path.find_last_of("\\/");
    if (path_end != std::string::npos)
        file_path = path.substr(0, path_end + 1);
    // Load the SketchUp model.
    
    enum SUModelLoadStatus status;
    SUResult result = SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);
    
    // It's best to always check the return code from each SU function call.
    // Only showing this check once to keep this example short.
    if (result != SU_ERROR_NONE){
        SUTerminate();
        return false;
    };
    
    SUEntitiesRef entities = SU_INVALID;
    result = SUModelGetEntities(model, &entities);
    
    if (result != SU_ERROR_NONE){
        SUModelRelease(&model);
        SUTerminate();
        return false;
    };
    
    SUMaterialRef white_material = create_color_material("Skalp White", 1.0, 255, 255, 255);
    process_all_entities(model, entities, white_material, "", fase, color_material);
    
    // Save the in-memory model to a file
    SUModelSaveToFile(model, path.c_str());
    
    //SUModelSaveToFile(model, path.c_str());
    
    // Must release the model or there will be memory leaks
    SUModelRelease(&model);
    
    // Always terminate the API when done using it
    SUTerminate();
    
    return true;
};
