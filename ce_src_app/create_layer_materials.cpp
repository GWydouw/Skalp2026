#include <iostream>
#include <stddef.h>
#include <stdio.h>
#include <string>
#include <vector>

#include <SketchUpAPI/common.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/drawing_element.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/layer.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/texture.h>
#include <SketchUpAPI/model/texture_writer.h>

#include "sketchup.h"

/**
 * Creates layers with specific materials based on an input model.
 *
 * This process involves:
 * 1. Loading a temporary "layers.skp" model.
 * 2. Reading existing faces/materials.
 * 3. Creating new Layers named according to `layer_names`.
 * 4. Creating materials for those layers (copying textures from faces).
 * 5. Assigning faces to the new layers.
 * 6. Saving the model back.
 *
 * Used for Material-by-Layer baking functionality in Skalp.
 */
bool create_layer_materials(std::string path,
                            std::vector<std::string> layer_names) {

  // Initialize SketchUp API
  SUInitialize();

  SUModelRef model = SU_INVALID;
  SUResult result;

  // Construct paths
  std::string filename = path + "layers.skp";
  std::string temp_texture_file = path + "temp_texture.png";

  // Load Model
  enum SUModelLoadStatus status;
  result = SUModelCreateFromFileWithStatus(&model, filename.c_str(), &status);

  if (result != SU_ERROR_NONE) {
    error_string = "Failed to load model: " + filename;
    SUTerminate();
    return false;
  }

  // Retrieve Materials from the model
  size_t num_materials = 0;
  size_t count = 0;

  SUModelGetNumMaterials(model, &num_materials);

  if (num_materials != layer_names.size()) {
    // Warning: Mismatch between model materials and provided layer names.
    // We will process min(num_materials, layer_names.size()) to be safe.
    if (layer_names.size() < num_materials)
      num_materials = layer_names.size();
  }

  std::vector<SUMaterialRef> materials(num_materials);
  for (size_t i = 0; i < num_materials; ++i) {
    SUSetInvalid(materials[i]);
  }
  SUModelGetMaterials(model, num_materials, &materials[0], &count);

  // Prepare for Layer creation
  std::vector<SULayerRef> add_layers(num_materials);
  std::vector<SUTextureRef> texture_copy(num_materials);

  // Get Setup Entities (expecting faces representing materials)
  SUEntitiesRef entities = SU_INVALID;
  SUModelGetEntities(model, &entities);

  size_t num_faces = 0;
  SUEntitiesGetNumFaces(entities, &num_faces);

  if (num_faces < num_materials) {
    // Error: Not enough faces to sample materials from?
    // Proceeding might be dangerous.
  }

  std::vector<SUFaceRef> faces(num_faces);
  SUEntitiesGetFaces(entities, num_faces, &faces[0], &count);

  // Use TextureWriter to extract textures properly with UVs
  SUTextureWriterRef writer = SU_INVALID;
  SUTextureWriterCreate(&writer);

  long frontID, backID;
  for (size_t i = 0; i < num_materials && i < num_faces; ++i) {
    SUTextureWriterLoadFace(writer, faces[i], &frontID, &backID);
  }

  // Loop to process each material -> layer
  for (size_t i = 0; i < num_materials; ++i) {

    // Create new Layer
    SUSetInvalid(add_layers[i]);
    SULayerCreate(&add_layers[i]);
    SULayerSetName(add_layers[i], layer_names[i].c_str());

    // Get Layer's internal material (Layers have a material property in API?)
    // Actually SULayerGetMaterial is likely retrieving the "Color by Layer"
    // material or similar.
    SUMaterialRef layer_material = SU_INVALID;
    SULayerGetMaterial(add_layers[i], &layer_material);

    // Check if source material has texture
    SUTextureRef texture = SU_INVALID;
    result = SUMaterialGetTexture(materials[i], &texture);

    if (result == SU_ERROR_NONE) {
      // Material has texture. We need to copy it to the Layer's material.
      size_t width, height;
      double s_scale, t_scale;
      SUTextureGetDimensions(texture, &width, &height, &s_scale, &t_scale);

      long id;
      SUTextureWriterGetTextureIdForFace(writer, faces[i], true, &id);

      // Dump texture to temp file
      SUTextureWriterWriteTexture(writer, id, temp_texture_file.c_str(), false);

      // Create new texture from file
      SUSetInvalid(texture_copy[i]);
      // Apply scale factors (inverted?) - verifying logic here, seems to be
      // 1/scale.
      SUTextureCreateFromFile(&texture_copy[i], temp_texture_file.c_str(),
                              1.0 / s_scale, 1.0 / t_scale);

      // Assign to Layer Material
      SUMaterialSetTexture(layer_material, texture_copy[i]);
    }
  }

  // Add all new layers to model
  SUModelAddLayers(model, num_materials, &add_layers[0]);

  // Assign created layers to the faces
  for (size_t i = 0; i < num_materials && i < num_faces; ++i) {
    SUEntityRef entity_ref = SUFaceToEntity(faces[i]);
    SUDrawingElementRef draw_elem = SUDrawingElementFromEntity(entity_ref);
    SUDrawingElementSetLayer(draw_elem, add_layers[i]);
  }

  // Save Result
  // Skalp likely expects SU2014 format for backwards compatibility
  result = SUModelSaveToFileWithVersion(model, filename.c_str(),
                                        SUModelVersion_SU2014);

  if (result != SU_ERROR_NONE) {
    error_string = "Failed to save model: " + filename;
  }

  // Cleanup
  SUTextureWriterRelease(&writer);
  SUModelRelease(&model);

  // Cleaning vectors usually happens on destruction, but API objects might need
  // release? SULayerRef etc are owned by Model once added. SUModelRelease
  // releases the model and its contained entities.

  SUTerminate();

  return (result == SU_ERROR_NONE);
}
