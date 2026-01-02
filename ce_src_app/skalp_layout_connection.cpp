#include "skalp_layout_connection.h"
#include "sketchup.h"
#include <algorithm>
#include <iostream>
#include <map>
#include <string>
#include <vector>

// LayOut API
#include <LayOutAPI/layout.h>
#include <LayOutAPI/model/document.h>
#include <LayOutAPI/model/group.h>
#include <LayOutAPI/model/page.h>
#include <LayOutAPI/model/pageinfo.h>
#include <LayOutAPI/model/sketchupmodel.h>

// SketchUp API
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/camera.h>
#include <SketchUpAPI/model/drawing_element.h>
#include <SketchUpAPI/model/entities.h>
#include <SketchUpAPI/model/group.h>
#include <SketchUpAPI/model/layer.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/typed_value.h>

struct SceneExportInfo {
  std::string name;
  std::string id;
  int orig_index;
  int sister_index;
  SUSceneRef orig_ref;
  SUSceneRef sister_ref;
  double scale;
  double model_w_in;
  double model_h_in;
};

// Helper to check for Skalp Scene
bool is_skalp_scene(SUSceneRef page) {
  SUEntityRef entity = SUSceneToEntity(page);
  SUAttributeDictionaryRef dictionary = SU_INVALID;
  SUResult res = SUEntityGetAttributeDictionary(entity, "Skalp", &dictionary);
  if (res != SU_ERROR_NONE || SUIsInvalid(dictionary))
    return false;

  SUTypedValueRef val = SU_INVALID;
  SUTypedValueCreate(&val);
  res = SUAttributeDictionaryGetValue(dictionary, "ID", &val);
  bool has_id = (res == SU_ERROR_NONE);
  SUTypedValueRelease(&val);
  return has_id;
}

// Helper to find the section group for a scene
SUGroupRef find_scene_section_group(SUModelRef model,
                                    const std::string &scene_id) {
  SUEntitiesRef model_entities = SU_INVALID;
  SUModelGetEntities(model, &model_entities);

  size_t num_groups = 0;
  SUEntitiesGetNumGroups(model_entities, &num_groups);
  std::vector<SUGroupRef> groups(num_groups);
  SUEntitiesGetGroups(model_entities, num_groups, &groups[0], &num_groups);

  for (SUGroupRef root_group : groups) {
    std::string is_result = get_attribute(SUGroupToEntity(root_group), "Skalp",
                                          "section_result_group");
    if (is_result == "true") {
      SUEntitiesRef child_entities = SU_INVALID;
      SUGroupGetEntities(root_group, &child_entities);
      size_t num_children = 0;
      SUEntitiesGetNumGroups(child_entities, &num_children);
      std::vector<SUGroupRef> children(num_children);
      SUEntitiesGetGroups(child_entities, num_children, &children[0],
                          &num_children);

      for (SUGroupRef child : children) {
        std::string id = get_attribute(SUGroupToEntity(child), "Skalp", "ID");
        if (id == scene_id) {
          return child;
        }
      }
    }
  }
  return SU_INVALID;
}

bool create_layout_scrapbook(std::string source_skp_path,
                             std::string output_layout_path,
                             std::string paper_size, bool show_debug) {

  if (show_debug)
    std::cout << "Starting create_layout_scrapbook..." << std::endl;

  SUInitialize();
  LOInitialize();

  SUModelRef model = SU_INVALID;
  SUResult res = SUModelCreateFromFile(&model, source_skp_path.c_str());
  if (res != SU_ERROR_NONE) {
    std::cerr << "Failed to load SKP model." << std::endl;
    SUTerminate();
    LOTerminate();
    return false;
  }

  size_t num_pages = 0;
  SUModelGetNumScenes(model, &num_pages);
  std::vector<SUSceneRef> all_pages(num_pages);
  SUModelGetScenes(model, num_pages, &all_pages[0], &num_pages);

  std::vector<SceneExportInfo> scenes_to_process;

  for (size_t i = 0; i < num_pages; i++) {
    if (is_skalp_scene(all_pages[i])) {
      SceneExportInfo info;
      info.orig_index = (int)i;
      info.orig_ref = all_pages[i];

      SUEntityRef ent = SUSceneToEntity(all_pages[i]);
      info.id = get_attribute(ent, "Skalp", "ID");
      info.name = get_attribute(ent, "Skalp", "name");
      if (info.name.empty()) {
        SUStringRef s_name = SU_INVALID;
        SUStringCreate(&s_name);
        SUSceneGetName(all_pages[i], &s_name);
        info.name = su_string_to_std_string(s_name);
        SUStringRelease(&s_name);
      }

      // Read Scale
      std::string scale_str = get_attribute(ent, "Skalp", "ss_drawing_scale");
      if (scale_str.empty()) {
        // Fallback to model attribute dictionary directly
        SUAttributeDictionaryRef m_dict = SU_INVALID;
        SUModelGetAttributeDictionary(model, "Skalp", &m_dict);
        if (SUIsValid(m_dict)) {
          SUTypedValueRef m_val = SU_INVALID;
          SUTypedValueCreate(&m_val);
          if (SUAttributeDictionaryGetValue(m_dict, "ss_drawing_scale",
                                            &m_val) == SU_ERROR_NONE) {
            SUTypedValueType m_type;
            SUTypedValueGetType(m_val, &m_type);
            if (m_type == SUTypedValueType_Double) {
              double d;
              SUTypedValueGetDouble(m_val, &d);
              scale_str = std::to_string((int)d);
            } else if (m_type == SUTypedValueType_String) {
              SUStringRef s = SU_INVALID;
              SUStringCreate(&s);
              SUTypedValueGetString(m_val, &s);
              scale_str = su_string_to_std_string(s);
              SUStringRelease(&s);
            }
          }
          SUTypedValueRelease(&m_val);
        }
      }
      info.scale = scale_str.empty() ? 50.0 : std::stod(scale_str);

      // Find Bounds
      SUGroupRef sect_group = find_scene_section_group(model, info.id);
      if (SUIsValid(sect_group)) {
        SUBoundingBox3D bbox;
        SUDrawingElementGetBoundingBox(SUGroupToDrawingElement(sect_group),
                                       &bbox);
        double dx = std::abs(bbox.max_point.x - bbox.min_point.x);
        double dy = std::abs(bbox.max_point.y - bbox.min_point.y);
        double dz = std::abs(bbox.max_point.z - bbox.min_point.z);

        std::vector<double> dims = {dx, dy, dz};
        std::sort(dims.begin(), dims.end());
        info.model_w_in = dims[2];
        info.model_h_in = dims[1];
      } else {
        info.model_w_in = 100.0;
        info.model_h_in = 100.0;
      }

      scenes_to_process.push_back(info);
    }
  }

  // 1.5 Create Sister Scenes
  size_t num_layers = 0;
  SUModelGetNumLayers(model, &num_layers);
  std::vector<SULayerRef> layers(num_layers);
  SUModelGetLayers(model, num_layers, &layers[0], &num_layers);
  SULayerRef section_layer = SU_INVALID;
  for (size_t i = 0; i < num_layers; i++) {
    SUStringRef n_ref = SU_INVALID;
    SUStringCreate(&n_ref);
    SULayerGetName(layers[i], &n_ref);
    std::string n = su_string_to_std_string(n_ref);
    SUStringRelease(&n_ref);
    if (n == "Skalp Scene Sections" || n == "\uFEFFSkalp Scene Sections") {
      section_layer = layers[i];
      break;
    }
  }

  for (auto &info : scenes_to_process) {
    SUSceneRef sister = SU_INVALID;
    SUSceneCreate(&sister);
    SUSceneSetName(sister, (info.name + "_Section").c_str());
    SUCameraRef camera = SU_INVALID;
    SUCameraCreate(&camera);
    SUSceneGetCamera(info.orig_ref, &camera);
    SUSceneSetCamera(sister, camera);
    if (SUIsValid(section_layer)) {
      SUSceneSetUseHiddenLayers(sister, true);
      for (SULayerRef layer : layers) {
        if (layer.ptr == section_layer.ptr)
          continue;
        SUSceneAddLayer(sister, layer);
      }
    }
    int out_idx = -1;
    SUModelAddScene(model, -1, sister, &out_idx);
    info.sister_index = out_idx;
  }

  SUModelSaveToFile(model, source_skp_path.c_str());
  SUModelRelease(&model);

  // 3. Generate LayOut
  LODocumentRef doc = SU_INVALID;
  LODocumentCreateEmpty(&doc);

  // Calculate Paper Size
  double max_p_w_pt = 200.0;
  double max_p_h_pt = 150.0;
  for (const auto &info : scenes_to_process) {
    double w_pt = (info.model_w_in * 72.0) / info.scale;
    double h_pt = (info.model_h_in * 72.0) / info.scale;
    max_p_w_pt = std::max(max_p_w_pt, w_pt);
    max_p_h_pt = std::max(max_p_h_pt, h_pt);
  }
  max_p_w_pt += 60.0; // Margin
  max_p_h_pt += 60.0;

  LOPageInfoRef page_info = SU_INVALID;
  LODocumentGetPageInfo(doc, &page_info);
  LOPageInfoSetWidth(page_info, max_p_w_pt);
  LOPageInfoSetHeight(page_info, max_p_h_pt);

  LOLayerRef lo_layer = SU_INVALID;
  LODocumentGetLayerAtIndex(doc, 0, &lo_layer);

  bool first_page = true;
  for (const auto &info : scenes_to_process) {
    LOPageRef page = SU_INVALID;
    if (first_page) {
      LODocumentGetPageAtIndex(doc, 0, &page);
      first_page = false;
    } else {
      LODocumentAddPage(doc, &page);
    }
    LOPageSetName(page, info.name.c_str());

    // Viewport Bounds
    double vp_w = (info.model_w_in * 72.0) / info.scale;
    double vp_h = (info.model_h_in * 72.0) / info.scale;
    LOAxisAlignedRect2D bounds = {{30, 30}, {30 + vp_w, 30 + vp_h}};

    // Create Viewports
    LOSketchUpModelRef vp1 = SU_INVALID;
    LOSketchUpModelCreate(&vp1, source_skp_path.c_str(), &bounds);
    LOSketchUpModelSetCurrentScene(vp1, info.orig_index);
    LOSketchUpModelSetScale(vp1, 1.0 / info.scale);
    LOSketchUpModelSetPreserveScaleOnResize(vp1, true);

    LOSketchUpModelRef vp2 = SU_INVALID;
    LOSketchUpModelCreate(&vp2, source_skp_path.c_str(), &bounds);
    LOSketchUpModelSetCurrentScene(vp2, info.sister_index);
    LOSketchUpModelSetScale(vp2, 1.0 / info.scale);
    LOSketchUpModelSetPreserveScaleOnResize(vp2, true);

    LODocumentAddEntity(doc, LOSketchUpModelToEntity(vp1), lo_layer, page);
    LODocumentAddEntity(doc, LOSketchUpModelToEntity(vp2), lo_layer, page);

    LOSketchUpModelRelease(&vp1);
    LOSketchUpModelRelease(&vp2);
  }

  LODocumentSaveToFile(doc, output_layout_path.c_str(),
                       LODocumentVersion_Current);
  LODocumentRelease(&doc);

  SUTerminate();
  LOTerminate();
  return true;
}
