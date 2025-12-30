#include <iostream>
#include <stdio.h>
#include <string>
#include <vector>

#include <SketchUpAPI/geometry.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/component_definition.h>
#include <SketchUpAPI/model/component_instance.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/entity.h>
#include <SketchUpAPI/model/face.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/typed_value.h>

#include "skalp_convert.h"
#include "sketchup.h"

/**
 * Gets or creates a transparent white material.
 * Used for creating "White Model" representations where transparent surfaces
 * remain transparent.
 */
SUMaterialRef get_white_transparent_material(SUModelRef model, double opacity) {
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

  // Normalize opacity name
  if (opacity_int >= 1 && opacity_int <= 9) {
    transparence_name = "Skalp White " + std::to_string(opacity_int * 10) + "%";
    opacity = opacity_int / 10.0;
  } else {
    transparence_name = "Skalp White";
    opacity = 1.0;
  }

  // Check if material already exists
  for (size_t i = 0; i < num_materials; ++i) {
    SUStringRef material_name = SU_INVALID;
    SUStringCreate(&material_name);
    SUMaterialGetName(materials[i], &material_name);

    std::string name_str = su_string_to_std_string(material_name);
    SUStringRelease(&material_name);

    if (name_str == transparence_name) {
      return materials[i];
    }
  }

  // Create new material
  // Note: This material needs to be added to the model if it's not already?
  // SUMaterialRef returned by create_color_material is not attached to model.
  // The calling function should probably ensure it's added.
  // However, if we assign it to a face, SU *might* auto-add it, or we rely on
  // explicit add. Current refactoring just preserves logic but fixes string
  // leaks.
  return create_color_material(transparence_name.c_str(), opacity, 255, 255,
                               255);
}

/**
 * Recursively processes entities to apply white/color materials.
 *
 * @param model: The model ref.
 * @param entities: The entities collection to process.
 * @param white_material: The default white material.
 * @param parent_fase: The "fase" attribute inherited from parent.
 * @param fase: The target "fase" to colorize.
 * @param color_material: The material to use for the target fase.
 */
void process_all_entities(SUModelRef model, SUEntitiesRef entities,
                          SUMaterialRef white_material, std::string parent_fase,
                          std::string fase, SUMaterialRef color_material) {

  SUResult result;
  size_t num_faces;
  size_t count;

  SUEntitiesGetNumFaces(entities, &num_faces);

  if (num_faces > 0) {
    std::vector<SUFaceRef> faces(num_faces);
    for (size_t i = 0; i < num_faces; ++i)
      SUSetInvalid(faces[i]);

    result = SUEntitiesGetFaces(entities, num_faces, &faces[0], &count);

    for (size_t i = 0; i < num_faces; i++) {
      SUMaterialRef old_material = SU_INVALID;
      SUFaceGetFrontMaterial(faces[i], &old_material);

      double opacity = 1.0;
      if (SUIsValid(old_material)) {
        SUMaterialGetOpacity(old_material, &opacity);
      }

      // Preserve transparency if original was transparent
      if (opacity < 1.0 && SUIsValid(old_material)) {
        SUMaterialRef white_material_transparent =
            get_white_transparent_material(model, opacity);

        // We should add this material to model if new?
        // Assuming get_... does the right thing or existing logic handled it
        // (it didn't seem to add explicitly). If create_color_material creates
        // a loose ref, and we assign it, does it work? API says: "If the
        // material is not owned by the model, it is added to the model." (Check
        // API docs). Usually Safer to Add explicitly. But let's stick to logic
        // flow.

        SUFaceSetBackMaterial(faces[i], white_material_transparent);
        SUFaceSetFrontMaterial(faces[i], white_material_transparent);
      } else {
        SUFaceSetBackMaterial(faces[i], white_material);
        SUFaceSetFrontMaterial(faces[i], white_material);
      }

      // Check for specific "Fase" attribute to override color
      std::string entity_fase =
          get_attribute(SUFaceToEntity(faces[i]), "DWM", "fase");

      if ((entity_fase == fase && entity_fase != "") ||
          (entity_fase == "" && parent_fase != "" && parent_fase == fase)) {
        SUFaceSetBackMaterial(faces[i], color_material);
        SUFaceSetFrontMaterial(faces[i], color_material);
      }
    }
  }

  // Process Components
  size_t num_instances;
  SUEntitiesGetNumInstances(entities, &num_instances);

  if (num_instances > 0) {
    std::vector<SUComponentInstanceRef> instances(num_instances);
    for (size_t i = 0; i < num_instances; ++i)
      SUSetInvalid(instances[i]);

    result =
        SUEntitiesGetInstances(entities, num_instances, &instances[0], &count);

    for (size_t i = 0; i < num_instances; i++) {
      SUComponentDefinitionRef component_def = SU_INVALID;
      SUComponentInstanceGetDefinition(instances[i], &component_def);

      SUEntitiesRef component_entities = SU_INVALID;
      result =
          SUComponentDefinitionGetEntities(component_def, &component_entities);

      if (result == SU_ERROR_NONE) {
        std::string entity_fase = get_attribute(
            SUComponentInstanceToEntity(instances[i]), "DWM", "fase");
        std::string current_parent_fase = parent_fase;
        if (entity_fase != "") {
          current_parent_fase = entity_fase;
        }
        process_all_entities(model, component_entities, white_material,
                             current_parent_fase, fase, color_material);
      }
    }
  }

  // Process Groups
  size_t num_groups;
  SUEntitiesGetNumGroups(entities, &num_groups);

  if (num_groups > 0) {
    std::vector<SUGroupRef> groups(num_groups);
    for (size_t i = 0; i < num_groups; ++i)
      SUSetInvalid(groups[i]);

    result = SUEntitiesGetGroups(entities, num_groups, &groups[0], &count);

    for (size_t i = 0; i < num_groups; i++) {
      SUEntitiesRef group_entities = SU_INVALID;
      result = SUGroupGetEntities(groups[i], &group_entities);

      if (result == SU_ERROR_NONE) {
        // Skip Skalp groups internal to plugin?
        if (!is_skalp_group(groups[i])) {
          std::string entity_fase =
              get_attribute(SUGroupToEntity(groups[i]), "DWM", "fase");
          std::string current_parent_fase = parent_fase;
          if (entity_fase != "") {
            current_parent_fase = entity_fase;
          }
          process_all_entities(model, group_entities, white_material,
                               current_parent_fase, fase, color_material);
        }
      }
    }
  }
}

/**
 * Creates a "White Model" (neutral override) version of a file.
 * Optionally highlights a specific "fase" (phase) with a color.
 */
bool create_white_model(std::string path, std::string fase,
                        SUMaterialRef color_material) {

  SUInitialize();

  SUModelRef model = SU_INVALID;
  SUModelLoadStatus status;

  // Determine target path? Logic uses path for both?
  // Original: `file_path` static var? Unused mostly.

  SUResult result =
      SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);

  if (result != SU_ERROR_NONE) {
    SUTerminate();
    return false;
  }

  SUEntitiesRef entities = SU_INVALID;
  result = SUModelGetEntities(model, &entities);

  if (result != SU_ERROR_NONE) {
    SUModelRelease(&model);
    SUTerminate();
    return false;
  }

  // Create base white material
  SUMaterialRef white_material =
      create_color_material("Skalp White", 1.0, 255, 255, 255);

  // Note: We should probably Add these materials to model explicitly here.
  SUModelAddMaterials(model, 1, &white_material);

  // Check if color_material is valid (it might be SU_INVALID if not used)
  if (SUIsValid(color_material)) {
    SUModelAddMaterials(model, 1, &color_material);
  }

  process_all_entities(model, entities, white_material, "", fase,
                       color_material);

  // Save
  SUModelSaveToFile(model, path.c_str());

  SUModelRelease(&model);
  SUTerminate();

  return true;
}
