#include <stdio.h>
#include <vector>
#include <string>
#include <stddef.h>

#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/common.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/texture_writer.h>
#include <SketchUpAPI/model/layer.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/texture.h>
#include <SketchUpAPI/model/drawing_element.h>

#include "sketchup.h"

bool create_layer_materials(std::string path, std::vector<std::string> layer_names){
    
    SUInitialize();
    SUModelRef model = SU_INVALID;
    SUResult result;
    
    // Load the SketchUp model
    std::string filename = path + "layers.skp";
    std::string temp_texture_file = path + "temp_texture.png";
    
    enum SUModelLoadStatus status;
    result = SUModelCreateFromFileWithStatus(&model, filename.c_str(), &status);
    
    if (result == SU_ERROR_MODEL_VERSION){
        return false;
    };
    
    // Load materials
    size_t num_materials;
    size_t count;
    
    SUModelGetNumMaterials(model, &num_materials);
    std::vector<SUMaterialRef> materials(num_materials);
    
    for (size_t i = 0; i < num_materials; ++i) {
        SUSetInvalid(materials[i]);
    }
    
    SUModelGetMaterials(model, num_materials, &materials[0], &count);
    
    // Create layers
    std::vector<SULayerRef> add_layers(num_materials);
    
    SUTextureRef texture = SU_INVALID;
    SUMaterialRef layer_material = SU_INVALID;
    size_t width, height;
    double s_scale, t_scale;
    
    std::vector<SUTextureRef> texture_copy(num_materials);
    
    // Get Entities
    
    SUEntitiesRef entities = SU_INVALID;
    SUModelGetEntities(model, &entities);
    
    size_t num_faces;
    SUEntitiesGetNumFaces(entities, &num_faces);
    
    std::vector<SUFaceRef> faces(num_faces);
    SUEntitiesGetFaces(entities, num_faces, &faces[0], &count);
    
    std::vector<SUEntityRef> entity(num_faces);
    SUDrawingElementRef drawing_element = SU_INVALID;
    
    SUTextureWriterRef writer = SU_INVALID;
    SUTextureWriterCreate(&writer);
    
    long frontID, backID;
    
    for (size_t i = 0; i < num_materials; ++i) {
        SUTextureWriterLoadFace(writer, faces[i], &frontID, &backID);
    }
    
    long id;
    
    for (size_t i = 0; i < num_materials; ++i) {
        
        SUSetInvalid(add_layers[i]);
        SUSetInvalid(texture_copy[i]);
        SULayerCreate(&add_layers[i]);
        
        SULayerSetName(add_layers[i], layer_names[i].c_str());
        
        SULayerGetMaterial(add_layers[i], &layer_material);
        result = SUMaterialGetTexture(materials[i], &texture);
        
        if (result == SU_ERROR_NONE){
            SUTextureGetDimensions(texture, &width, &height, &s_scale, &t_scale);
            
            //SUTextureWriteToFile(texture, temp_texture_file.c_str());
            
            SUTextureWriterGetTextureIdForFace(writer, faces[i], true, &id);
            SUTextureWriterWriteTexture(writer, id, temp_texture_file.c_str(), false);
            
            SUTextureCreateFromFile(&texture_copy[i], temp_texture_file.c_str(), 1.0/s_scale, 1.0/t_scale);
            SUMaterialSetTexture(layer_material, texture_copy[i]);
        }
    }
    
    SUModelAddLayers(model, num_materials, &add_layers[0]);
    
    for (size_t i = 0; i < num_materials; ++i) {
        SUSetInvalid(entity[i]);
        entity[i] = SUFaceToEntity(faces[i]);
        drawing_element = SUDrawingElementFromEntity(entity[i]);
        SUDrawingElementSetLayer(drawing_element, add_layers[i]);
    }
    
    // Save the in-memory model to a file
    SUModelSaveToFileWithVersion(model, filename.c_str(), SUModelVersion_SU2014);
    
    //Release model
    SUTextureWriterRelease(&writer);
    SUModelRelease(&model);
    add_layers.clear();
    materials.clear();
    texture_copy.clear();
    entity.clear();
    SUTerminate();
    
    return true;
}
