#include <iostream>
#include <stdio.h>
#include <string>
#include <vector>

#include <SketchUpAPI/geometry.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/camera.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/entity.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/material.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/section_plane.h>
#include <SketchUpAPI/model/texture.h>
#include <SketchUpAPI/model/typed_value.h>

#include "sketchup.h"

/**
 * Removes textures from all materials in the model, making them just colored.
 */
bool remove_materials(SUModelRef model) {
  SUResult result;
  size_t num_materials;
  size_t count;

  SUModelGetNumMaterials(model, &num_materials);
  if (num_materials == 0)
    return true;

  std::vector<SUMaterialRef> materials(num_materials);
  for (size_t i = 0; i < num_materials; ++i)
    SUSetInvalid(materials[i]);

  SUModelGetMaterials(model, num_materials, &materials[0], &count);

  for (size_t i = 0; i < num_materials; ++i) {
    SUTextureRef texture = SU_INVALID;
    result = SUMaterialGetTexture(materials[i], &texture);

    if (result == SU_ERROR_NONE && SUIsValid(texture)) {
      // If it has a texture, force it to be color-only (removing texture
      // reference effectively) Note: SUMaterialSetType alone might not remove
      // texture, but changes how it's rendered? Actually API docs say
      // Type_Colored ignores texture.
      SUMaterialSetType(materials[i], SUMaterialType_Colored);
    }
  }
  return true;
}

/**
 * Finds the "Skalp sections" group.
 */
SUEntitiesRef get_sectiongroups(SUEntitiesRef entities) {
  // std::cout << "get_sectiongroups" << std::endl;
  SUEntitiesRef section_group_entities = SU_INVALID;

  SUResult result;
  size_t num_groups;
  size_t count;

  SUEntitiesGetNumGroups(entities, &num_groups);
  if (num_groups == 0)
    return section_group_entities;

  std::vector<SUGroupRef> groups(num_groups);
  for (size_t i = 0; i < num_groups; ++i)
    SUSetInvalid(groups[i]);

  result = SUEntitiesGetGroups(entities, num_groups, &groups[0], &count);

  for (size_t i = 0; i < num_groups; i++) {
    SUStringRef group_name = SU_INVALID;
    SUStringCreate(&group_name);
    SUGroupGetName(groups[i], &group_name);

    std::string name_str = su_string_to_std_string(group_name);
    SUStringRelease(&group_name);

    if (name_str == "Skalp sections") {
      SUGroupGetEntities(groups[i], &section_group_entities);
      return section_group_entities;
    }
  }

  return section_group_entities;
}

/**
 * Moves a specific section group identified by Ruby ID.
 */
bool move_section_group(SUEntitiesRef entities, std::string ruby_id,
                        SUTransformation transformation) {
  // If invalid entities, return
  if (SUIsInvalid(entities))
    return false;

  SUResult result;
  size_t num_groups;
  size_t count;

  SUEntitiesGetNumGroups(entities, &num_groups);
  if (num_groups == 0)
    return true; // Nothing to move

  std::vector<SUGroupRef> groups(num_groups);
  for (size_t i = 0; i < num_groups; ++i)
    SUSetInvalid(groups[i]);

  result = SUEntitiesGetGroups(entities, num_groups, &groups[0], &count);

  for (size_t i = 0; i < num_groups; i++) {

    SUEntityRef entity = SUGroupToEntity(groups[i]);

    // Use helper to get attribute safely
    // But get_attribute returns string. We need to check if it matches ruby_id.

    std::string val = get_attribute(entity, "Skalp", "ID");
    if (!val.empty() && val == ruby_id) {
      result = SUGroupSetTransform(groups[i], &transformation);
      if (result != SU_ERROR_NONE)
        return false;
      // Found and moved.
      // Should we return or continue? Assumption: ID is unique.
    }
  }
  return true;
}

/**
 * Sets up a reversed scene?
 * It seems to be creating orthogonal views for sections, reversing section
 * planes, and applying transforms.
 */
bool setup_reversed_scene(std::string path, std::string new_path,
                          std::vector<int> page_index_array,
                          std::vector<SUPoint3D> eye_array,
                          std::vector<SUPoint3D> target_array,
                          std::vector<SUTransformation> transformation_array,
                          std::vector<std::string> id_array,
                          std::vector<SUVector3D> up_vector_array,
                          double bounds) {
  SUInitialize();

  SUModelRef model = SU_INVALID;
  SUModelLoadStatus status;
  SUResult result =
      SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);

  if (result != SU_ERROR_NONE) {
    return false;
  }

  SUEntitiesRef entities = SU_INVALID;
  result = SUModelGetEntities(model, &entities);

  if (result != SU_ERROR_NONE) {
    SUModelRelease(&model);
    SUTerminate();
    return false;
  }

  // --- Reverse Section Planes ---
  size_t num_sectionplanes;
  size_t count;
  SUEntitiesGetNumSectionPlanes(entities, &num_sectionplanes);

  if (num_sectionplanes > 0) {
    std::vector<SUSectionPlaneRef> sectionplanes(num_sectionplanes);
    for (size_t i = 0; i < num_sectionplanes; ++i)
      SUSetInvalid(sectionplanes[i]);

    SUEntitiesGetSectionPlanes(entities, num_sectionplanes, &sectionplanes[0],
                               &count);

    for (size_t i = 0; i < num_sectionplanes; i++) {
      SUPlane3D plane = {0, 0, 0, 0};
      SUPlane3D newplane = {0, 0, 0, 0};
      SUSectionPlaneGetPlane(sectionplanes[i], &plane);
      // Reverse plane normal and distance
      newplane.a = -plane.a;
      newplane.b = -plane.b;
      newplane.c = -plane.c;
      newplane.d = -plane.d;
      SUSectionPlaneSetPlane(sectionplanes[i], &newplane);
    }
  }

  // --- Process Scenes / Cameras ---

  SUEntitiesRef section_group_entities = get_sectiongroups(entities);

  if (SUIsInvalid(section_group_entities)) {
    // std::cout << "sectiongroup NOT found" << std::endl;
    // Proceeding might fail if move_section_group depends on it?
    // move_section_group checks constraints.
  }

  // Cache scenes lookup?
  size_t num_scenes;
  SUModelGetNumScenes(model, &num_scenes);
  std::vector<SUSceneRef> scenes(num_scenes);
  for (size_t k = 0; k < num_scenes; ++k)
    SUSetInvalid(scenes[k]);
  SUModelGetScenes(model, num_scenes, &scenes[0], &count);

  size_t operations_count = page_index_array.size();

  for (size_t j = 0; j < operations_count; ++j) {
    int page_index = page_index_array[j];

    SUPoint3D new_target = target_array[j];
    SUPoint3D new_eye = eye_array[j];
    SUVector3D new_up_vector = up_vector_array[j];

    // This function handles invalid entity ref gracefully
    move_section_group(section_group_entities, id_array[j],
                       transformation_array[j]);

    if (page_index != -1) {
      // Modifying a specific Scene
      if (page_index >= 0 && page_index < num_scenes) {
        SUCameraRef scene_cam = SU_INVALID;
        SUSceneGetCamera(scenes[page_index], &scene_cam);

        // If scene has no camera (uses modeleditors?), we might need to
        // create/copy? API: SUSceneGetCamera returns the camera of the scene.

        SUCameraSetOrientation(scene_cam, &new_eye, &new_target,
                               &new_up_vector);
        SUCameraSetPerspective(scene_cam, false); // Ortho
        SUCameraSetOrthographicFrustumHeight(scene_cam, bounds);

        // Set back to scene? SUSceneSetCamera copies details?
        // Not strictly necessary if scene_cam is reference to internal object?
        // API usually requires Set.
        SUSceneSetCamera(scenes[page_index], scene_cam);
      }
    } else {
      // Modifying the Model's active view logic? Or a temp camera?
      // "Else" branch in original code seemed to modify Model Camera?

      SUCameraRef camera = SU_INVALID;
      SUModelGetCamera(model, &camera);

      SUCameraSetOrientation(camera, &new_eye, &new_target, &new_up_vector);
      SUCameraSetPerspective(camera, false);
      SUCameraSetOrthographicFrustumHeight(camera, bounds);

      SUModelSetCamera(model, &camera);
    }
  }

  remove_materials(model);

  SUModelSaveToFileWithVersion(model, new_path.c_str(), SUModelVersion_Current);

  SUModelRelease(&model);
  SUTerminate();
  return true;
}
