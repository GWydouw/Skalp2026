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
#include <LayOutAPI/model/entitylist.h>
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
  double scale;
  double model_w_in;
  double model_h_in;
  bool is_ortho;
};

// Helper: Check for Skalp Scene
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

// Helper: Find section group
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
        if (get_attribute(SUGroupToEntity(child), "Skalp", "ID") == scene_id)
          return child;
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
  if (SUModelCreateFromFile(&model, source_skp_path.c_str()) != SU_ERROR_NONE) {
    SUTerminate();
    LOTerminate();
    return false;
  }

  size_t num_scenes = 0;
  SUModelGetNumScenes(model, &num_scenes);
  std::vector<SUSceneRef> all_scenes(num_scenes);
  SUModelGetScenes(model, num_scenes, &all_scenes[0], &num_scenes);

  std::map<std::string, int> scene_map;
  for (size_t i = 0; i < num_scenes; i++) {
    SUStringRef s_name = SU_INVALID;
    SUStringCreate(&s_name);
    SUSceneGetName(all_scenes[i], &s_name);
    scene_map[su_string_to_std_string(s_name)] = (int)i;
    SUStringRelease(&s_name);
  }

  std::vector<SceneExportInfo> scenes_to_process;
  for (size_t i = 0; i < num_scenes; i++) {
    if (is_skalp_scene(all_scenes[i])) {
      SceneExportInfo info;
      info.orig_index = (int)i;
      SUEntityRef ent = SUSceneToEntity(all_scenes[i]);
      info.id = get_attribute(ent, "Skalp", "ID");

      SUStringRef s_name = SU_INVALID;
      SUStringCreate(&s_name);
      SUSceneGetName(all_scenes[i], &s_name);
      info.name = su_string_to_std_string(s_name);
      SUStringRelease(&s_name);

      std::string sister_name = info.name + "_Section";
      info.sister_index =
          scene_map.count(sister_name) ? scene_map[sister_name] : (int)i;

      std::string scale_str = get_attribute(ent, "Skalp", "ss_drawing_scale");
      if (scale_str.empty()) {
        SUAttributeDictionaryRef m_dict = SU_INVALID;
        SUModelGetAttributeDictionary(model, "Skalp", &m_dict);
        if (SUIsValid(m_dict)) {
          SUTypedValueRef m_val = SU_INVALID;
          SUTypedValueCreate(&m_val);
          if (SUAttributeDictionaryGetValue(m_dict, "ss_drawing_scale",
                                            &m_val) == SU_ERROR_NONE) {
            SUTypedValueType type;
            SUTypedValueGetType(m_val, &type);
            if (type == SUTypedValueType_Double) {
              double d;
              SUTypedValueGetDouble(m_val, &d);
              scale_str = std::to_string((int)d);
            } else if (type == SUTypedValueType_String) {
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

      SUCameraRef camera = SU_INVALID;
      SUSceneGetCamera(all_scenes[i], &camera);
      bool perspective = true;
      SUCameraGetPerspective(camera, &perspective);
      info.is_ortho = !perspective;

      scenes_to_process.push_back(info);
    }
  }
  SUModelRelease(&model);

  // Generate LayOut
  LODocumentRef doc = SU_INVALID;
  LODocumentCreateEmpty(&doc);

  // Set Units: Decimal Centimeters, Precision 0.01 (2 decimal places)
  LODocumentSetUnits(doc, LODocumentUnits_DecimalCentimeters, 0.01);

  double max_vp_w = 0, max_vp_h = 0;
  for (const auto &info : scenes_to_process) {
    if (info.is_ortho) {
      max_vp_w = std::max(max_vp_w, (info.model_w_in * 72.0) / info.scale);
      max_vp_h = std::max(max_vp_h, (info.model_h_in * 72.0) / info.scale);
    }
  }
  // Fallback if no ortho scenes
  if (max_vp_w == 0) {
    max_vp_w = 500.0;
    max_vp_h = 400.0;
  }

  double max_p_w_pt = max_vp_w + 60.0; // Margin ~2cm
  double max_p_h_pt = max_vp_h + 60.0;

  LOPageInfoRef page_info = SU_INVALID;
  LODocumentGetPageInfo(doc, &page_info);
  LOPageInfoSetWidth(page_info, max_p_w_pt);
  LOPageInfoSetHeight(page_info, max_p_h_pt);

  LOLayerRef lo_layer = SU_INVALID;
  LODocumentGetLayerAtIndex(doc, 0, &lo_layer);

  for (size_t i = 0; i < scenes_to_process.size(); i++) {
    const auto &info = scenes_to_process[i];
    LOPageRef page = SU_INVALID;
    if (i == 0)
      LODocumentGetPageAtIndex(doc, 0, &page);
    else
      LODocumentAddPage(doc, &page);
    LOPageSetName(page, info.name.c_str());

    double vp_w =
        info.is_ortho ? (info.model_w_in * 72.0) / info.scale : max_vp_w;
    double vp_h =
        info.is_ortho ? (info.model_h_in * 72.0) / info.scale : max_vp_h;

    // Position top-left (1mm = 2.835 pt margin)
    double margin = 2.835;
    LOAxisAlignedRect2D bounds = {{margin, margin},
                                  {margin + vp_w, margin + vp_h}};

    LOSketchUpModelRef vp1 = SU_INVALID;
    LOSketchUpModelCreate(&vp1, source_skp_path.c_str(), &bounds);
    LOSketchUpModelSetCurrentScene(vp1, info.orig_index);
    if (info.is_ortho) {
      LOSketchUpModelSetPerspective(vp1, false);
      LOSketchUpModelSetScale(vp1, 1.0 / info.scale);
    } else {
      LOSketchUpModelSetPerspective(vp1, true);
    }
    LOSketchUpModelSetPreserveScaleOnResize(vp1, true);
    LOSketchUpModelSetRenderMode(vp1, LOSketchUpModelRenderMode_Hybrid);

    LOSketchUpModelRef vp2 = SU_INVALID;
    LOSketchUpModelCreate(&vp2, source_skp_path.c_str(), &bounds);
    LOSketchUpModelSetCurrentScene(vp2, info.sister_index);
    if (info.is_ortho) {
      LOSketchUpModelSetPerspective(vp2, false);
      LOSketchUpModelSetScale(vp2, 1.0 / info.scale);
    } else {
      LOSketchUpModelSetPerspective(vp2, true);
    }
    LOSketchUpModelSetPreserveScaleOnResize(vp2, true);

    // Set to Hybrid mode as requested
    LOSketchUpModelSetRenderMode(vp2, LOSketchUpModelRenderMode_Hybrid);
    LOSketchUpModelSetDisplayBackground(vp2, false);

    // Create Group
    LOEntityListRef list = SU_INVALID;
    LOEntityListCreate(&list);
    LOEntityListAddEntity(list, LOSketchUpModelToEntity(vp1));
    LOEntityListAddEntity(list, LOSketchUpModelToEntity(vp2));

    LOGroupRef group = SU_INVALID;
    LOGroupCreate(&group, list); // Corrected argument order
    LODocumentAddEntity(doc, LOGroupToEntity(group), lo_layer, page);

    // Release refs
    LOEntityListRelease(&list);
    LOSketchUpModelRelease(&vp1);
    LOSketchUpModelRelease(&vp2);
    LOGroupRelease(&group);
  }

  LODocumentSaveToFile(doc, output_layout_path.c_str(),
                       LODocumentVersion_Current);
  LODocumentRelease(&doc);

  SUTerminate();
  LOTerminate();
  return true;
}
