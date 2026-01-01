#include <iostream>
#include <map>
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
#include <SketchUpAPI/model/rendering_options.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/section_plane.h>
#include <SketchUpAPI/model/style.h>
#include <SketchUpAPI/model/styles.h>
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
 * Iterates through all scenes in the model and overrides their rendering
 * options to match Skalp's hidden-line requirements.
 */
/**
 * Loads a style from file and applies it to all scenes in the model.
 */
bool load_and_apply_style(SUModelRef model, const std::string &style_path) {
  SUStylesRef styles = SU_INVALID;
  SUModelGetStyles(model, &styles);
  if (SUIsInvalid(styles))
    return false;

  // Add the style and activate it so we can retrieve it
  SUResult res = SUStylesAddStyle(styles, style_path.c_str(), true);
  if (res != SU_ERROR_NONE) {
    std::cerr << "[C++] Failed to add style from: " << style_path
              << " (Error: " << res << ")" << std::endl;
    // Attempt to proceed if it was a duplicate?
    if (res != SU_ERROR_DUPLICATE)
      return false;
  } else {
    std::cerr << "[C++] Style added: " << style_path << std::endl;
  }

  // Get the active style (which should be the one we just added/activated)
  SUStyleRef style = SU_INVALID;
  res = SUStylesGetActiveStyle(styles, &style);
  if (res != SU_ERROR_NONE || SUIsInvalid(style)) {
    std::cerr << "[C++] Failed to get active style." << std::endl;
    return false;
  }

  size_t num_scenes = 0;
  SUModelGetNumScenes(model, &num_scenes);
  if (num_scenes == 0)
    return true;

  std::vector<SUSceneRef> scenes(num_scenes);
  SUModelGetScenes(model, num_scenes, &scenes[0], &num_scenes);

  for (size_t i = 0; i < num_scenes; ++i) {
    // Apply the style to the scene
    res = SUStylesApplyStyleToScene(styles, style, scenes[i]);
    if (res != SU_ERROR_NONE) {
      std::cerr << "[C++] Failed to apply style to scene " << i
                << " Error: " << res << std::endl;
    }
  }

  std::cerr << "[C++] Style applied to all scenes." << std::endl;
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

// Helper to find section planes in a generic entities collection
void collect_section_planes(SUEntitiesRef entities,
                            std::map<std::string, SUSectionPlaneRef> &map) {
  if (SUIsInvalid(entities))
    return;

  size_t num_sectionplanes;
  SUEntitiesGetNumSectionPlanes(entities, &num_sectionplanes);
  if (num_sectionplanes > 0) {
    std::vector<SUSectionPlaneRef> planes(num_sectionplanes);
    size_t count;
    SUEntitiesGetSectionPlanes(entities, num_sectionplanes, &planes[0], &count);
    for (size_t i = 0; i < count; ++i) {
      std::string sid =
          get_attribute(SUSectionPlaneToEntity(planes[i]), "Skalp", "ID");
      if (!sid.empty()) {
        map[sid] = planes[i];
      }
    }
  }
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
                          std::vector<std::string> sectionplane_id_array,
                          double bounds, std::string style_path) {
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

  // --- Flatten Sections Strategy ---
  // Iterate the "Skalp sections" group, find all planes, and recreate them in
  // the Model Root. This ensures we can easily activate them without worrying
  // about nested paths.

  std::map<std::string, SUSectionPlaneRef> sectionplane_map;
  SUEntitiesRef section_group_entities = get_sectiongroups(entities);

  if (!SUIsInvalid(section_group_entities)) {
    size_t num_group_planes;
    SUEntitiesGetNumSectionPlanes(section_group_entities, &num_group_planes);
    if (num_group_planes > 0) {
      std::vector<SUSectionPlaneRef> g_planes(num_group_planes);
      size_t count;
      SUEntitiesGetSectionPlanes(section_group_entities, num_group_planes,
                                 &g_planes[0], &count);

      for (size_t i = 0; i < count; ++i) {
        std::string sid =
            get_attribute(SUSectionPlaneToEntity(g_planes[i]), "Skalp", "ID");
        if (!sid.empty()) {
          // Get properties
          SUPlane3D eq;
          SUSectionPlaneGetPlane(g_planes[i], &eq);

          // Create NEW plane in ROOT
          SUSectionPlaneRef new_plane = SU_INVALID;
          SUSectionPlaneCreate(&new_plane);
          SUSectionPlaneSetPlane(new_plane, &eq);

          // Copy ID
          SUAttributeDictionaryRef dict = SU_INVALID;
          SUEntityGetAttributeDictionary(SUSectionPlaneToEntity(new_plane),
                                         "Skalp", &dict);
          if (SUIsInvalid(dict)) {
            SUAttributeDictionaryCreate(&dict, "Skalp");
            SUEntityAddAttributeDictionary(SUSectionPlaneToEntity(new_plane),
                                           dict);
          }
          SUTypedValueRef val = SU_INVALID;
          SUTypedValueCreate(&val);
          SUTypedValueSetString(val, sid.c_str());
          SUAttributeDictionarySetValue(dict, "ID", val);
          SUTypedValueRelease(&val);

          // Add to Root Entities
          SUEntitiesAddSectionPlanes(entities, 1, &new_plane);

          // Map it
          sectionplane_map[sid] = new_plane;
        }
      }
    }

    // Also grab any existing root planes just in case
    collect_section_planes(entities, sectionplane_map);
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
    // Note: section_group_entities might be invalid if we flattened everything?
    // Actually we keep the group but we ALSO copied the planes.
    // We still move the group just in case other geometry is in it.
    move_section_group(section_group_entities, id_array[j],
                       transformation_array[j]);

    if (page_index != -1) {
      if (page_index >= 0 && page_index < num_scenes) {
        std::cerr << "[C++] Processing scene index: " << page_index
                  << " eye: " << new_eye.x << "," << new_eye.y << ","
                  << new_eye.z << std::endl;

        SUSceneSetUseCamera(scenes[page_index], true);
        SUSceneSetUseSectionPlanes(scenes[page_index], true);

        // 2. Enable scene-specific rendering options to respect the Per-Scene
        // styles (which we will modify in Ruby just before export)
        SUSceneSetUseRenderingOptions(scenes[page_index], true);

        // Debug Style
        SUStyleRef style = SU_INVALID;
        SUSceneGetStyle(scenes[page_index], &style);
        if (!SUIsInvalid(style)) {
          SUStringRef name = SU_INVALID;
          SUStringCreate(&name);
          SUStyleGetName(style, &name);
          size_t name_l;
          SUStringGetUTF8Length(name, &name_l);
          char *name_c = new char[name_l + 1];
          SUStringGetUTF8(name, name_l + 1, name_c, &name_l);
          std::cerr << "[C++] Scene Style: " << name_c << std::endl;
          delete[] name_c;
          SUStringRelease(&name);
        } else {
          std::cerr << "[C++] Scene Style: INVALID/DEFAULT" << std::endl;
        }

        if (j < sectionplane_id_array.size()) {
          std::string target_sid = sectionplane_id_array[j];
          // Check if key exists using find to avoid accidental insertion
          // (though [] does that, count is safer)
          if (!target_sid.empty() && sectionplane_map.count(target_sid) > 0) {

            // Activate plane on ROOT entities (since we flattened them)
            SUEntitiesSetActiveSectionPlane(entities,
                                            sectionplane_map[target_sid]);
            SUSceneUpdate(scenes[page_index], FLAG_USE_SECTION_PLANES);
            std::cerr << "[C++] Activated ROOT section plane ID: " << target_sid
                      << " for scene " << page_index << std::endl;
          }
        }

        SUCameraRef scene_cam = SU_INVALID;
        SUCameraCreate(&scene_cam);

        // Debug Log Camera
        std::cerr << "[C++] Cam Set: Eye(" << new_eye.x << "," << new_eye.y
                  << "," << new_eye.z << ") "
                  << "Target(" << new_target.x << "," << new_target.y << ","
                  << new_target.z << ") "
                  << "Up(" << new_up_vector.x << "," << new_up_vector.y << ","
                  << new_up_vector.z << ") "
                  << "Height: " << bounds << std::endl;

        SUCameraSetOrientation(scene_cam, &new_eye, &new_target,
                               &new_up_vector);
        SUCameraSetPerspective(scene_cam, false);
        SUCameraSetOrthographicFrustumHeight(scene_cam, bounds);

        SUResult res = SUSceneSetCamera(scenes[page_index], scene_cam);
        if (res != SU_ERROR_NONE) {
          std::cerr << "[C++] ERROR setting camera for scene " << page_index
                    << " code: " << res << std::endl;
        } else {
          std::cerr << "[C++] Camera set successfully for scene " << page_index
                    << std::endl;
        }
        SUCameraRelease(&scene_cam);
      } else {
        std::cerr << "[C++] ERROR: scene index " << page_index
                  << " out of bounds (max " << num_scenes << ")" << std::endl;
      }
    } else {
      std::cerr << "[C++] Processing model camera eye: " << new_eye.x << ","
                << new_eye.y << "," << new_eye.z << std::endl;

      // Also activate section plane for model root (Active View)
      if (j < sectionplane_id_array.size()) {
        std::string target_sid = sectionplane_id_array[j];
        if (!target_sid.empty() && sectionplane_map.count(target_sid) > 0) {
          SUEntitiesSetActiveSectionPlane(entities,
                                          sectionplane_map[target_sid]);
          std::cerr << "[C++] Activated ROOT section plane ID: " << target_sid
                    << " for model root" << std::endl;
        }
      }

      SUCameraRef camera = SU_INVALID;
      SUModelGetCamera(model, &camera);
      SUCameraSetOrientation(camera, &new_eye, &new_target, &new_up_vector);
      SUCameraSetPerspective(camera, false);
      SUCameraSetOrthographicFrustumHeight(camera, bounds);
      // SUModelSetCamera(model, &camera); // Not needed as we modified the
      // camera ref
    }
  }

  // Set Global Rendering Options (Backup, though scenes use their own styles
  // now) apply_skalp_rendering_settings(model); // REMOVED: Redundant and
  // incomplete . We rely on the input file having correct styles (manipulated
  // by Ruby within a transaction).

  // Apply Skalp Style (To all scenes) - Replaces previous overrides
  if (!style_path.empty() && style_path != "\"\"" && style_path != "''") {
    load_and_apply_style(model, style_path);
  }

  // Clean up unused materials
  remove_materials(model);

  SUModelSaveToFileWithVersion(model, new_path.c_str(), SUModelVersion_Current);

  SUModelRelease(&model);
  SUTerminate();
  return true;
}
