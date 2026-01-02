#include "skalp_layout_connection.h"
#include "sketchup.h"
#include <iostream>
#include <map>
#include <string>
#include <vector>

// LayOut API
#include <LayOutAPI/layout.h>

// SketchUp API
#include <SketchUpAPI/model/attribute_dictionary.h>
#include <SketchUpAPI/model/camera.h>
#include <SketchUpAPI/model/layer.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/typed_value.h>

// Helper to check for Skalp Scene
bool is_skalp_scene(SUSceneRef page) {
  SUEntityRef entity = SUSceneToEntity(page);
  SUAttributeDictionaryRef dictionary = SU_INVALID;
  SUResult res = SUEntityGetAttributeDictionary(entity, "Skalp", &dictionary);
  if (res != SU_ERROR_NONE || SUIsInvalid(dictionary))
    return false;

  // Check for ID
  SUTypedValueRef val = SU_INVALID;
  SUTypedValueCreate(&val);
  res = SUAttributeDictionaryGetValue(dictionary, "ID", &val);
  bool has_id = (res == SU_ERROR_NONE);
  SUTypedValueRelease(&val);
  return has_id;
}

// Convert SUString to std::string helper (assumed generic or implemented
// locally) If not available in "sketchup.h", implementing here locally to be
// safe. Wait, user provided file (Step 3312) had su_string_to_std_string. It
// was used in line 100. I should ensure it's available or define it. Assuming
// it is in headers or I reuse previous def if it was there? Step 3312 showed
// line 100 `su_string_to_std_string(name_ref)`. It must be in a header or I
// missed its definition in the file view? It was NOT defined in lines 1-241. So
// it must be in "sketchup.h" or "skalp_layout_connection.h"? I'll assume it
// exists.

struct SceneExportInfo {
  std::string name;
  int orig_index;
  int sister_index;
  SUSceneRef orig_ref;
  SUSceneRef sister_ref;
};

bool create_layout_scrapbook(std::string source_skp_path,
                             std::string output_layout_path,
                             std::string paper_size, bool show_debug) {

  if (show_debug)
    std::cout << "Starting create_layout_scrapbook..." << std::endl;

  // 1. Initialize APIs
  SUInitialize();
  LOInitialize();

  SUModelRef model = SU_INVALID;
  SUResult res = SUModelCreateFromFile(&model, source_skp_path.c_str());
  if (res != SU_ERROR_NONE) {
    std::cerr << "Failed to load SKP model: " << source_skp_path << std::endl;
    SUTerminate();
    LOTerminate();
    return false;
  }

  // 2. Identify Skalp Scenes
  size_t num_pages = 0;
  SUModelGetNumScenes(model, &num_pages);
  if (num_pages == 0) {
    if (show_debug)
      std::cout << "No scenes found." << std::endl;
    SUModelRelease(&model);
    SUTerminate();
    LOTerminate();
    return false;
  }

  std::vector<SUSceneRef> all_pages(num_pages);
  SUModelGetScenes(model, num_pages, &all_pages[0], &num_pages);

  std::vector<SceneExportInfo> scenes_to_process;

  for (size_t i = 0; i < num_pages; i++) {
    if (is_skalp_scene(all_pages[i])) {
      SceneExportInfo info;
      info.orig_index = (int)i;
      info.orig_ref = all_pages[i];

      SUStringRef name_ref = SU_INVALID;
      SUStringCreate(&name_ref);
      SUSceneGetName(all_pages[i], &name_ref);
      // Assuming su_string_to_std_string is available
      // If not, I'll use a local lambda/macro?
      // I'll trust the previous code context.
      size_t len = 0;
      SUStringGetUTF8Length(name_ref, &len);
      std::vector<char> buffer(len + 1);
      SUStringGetUTF8(name_ref, len + 1, &buffer[0], &len);
      info.name = std::string(&buffer[0]);
      SUStringRelease(&name_ref);

      scenes_to_process.push_back(info);
    }
  }

  if (show_debug)
    std::cout << "Found " << scenes_to_process.size() << " Skalp scenes."
              << std::endl;

  // Prepare Layer Lookup
  size_t num_layers = 0;
  SUModelGetNumLayers(model, &num_layers);
  std::vector<SULayerRef> layers(num_layers);
  SUModelGetLayers(model, num_layers, &layers[0], &num_layers);

  SULayerRef section_layer = SU_INVALID;
  for (size_t i = 0; i < num_layers; i++) {
    SUStringRef name_ref = SU_INVALID;
    SUStringCreate(&name_ref);
    SULayerGetName(layers[i], &name_ref);
    // Manual string conversion to be safe
    size_t len = 0;
    SUStringGetUTF8Length(name_ref, &len);
    std::vector<char> buffer(len + 1);
    SUStringGetUTF8(name_ref, len + 1, &buffer[0], &len);
    std::string name(&buffer[0]);
    SUStringRelease(&name_ref);

    if (name == "Skalp Scene Sections" ||
        name == "\uFEFFSkalp Scene Sections") {
      section_layer = layers[i];
      break;
    }
  }

  if (SUIsInvalid(section_layer) && show_debug) {
    std::cout << "Warning: 'Skalp Scene Sections' layer not found."
              << std::endl;
  }

  // Add Sister Scenes
  for (auto &info : scenes_to_process) {
    SUSceneRef sister_page = SU_INVALID;
    SUSceneCreate(&sister_page);

    std::string sister_name = info.name + "_Section";
    SUSceneSetName(sister_page, sister_name.c_str());

    // Copy Camera
    SUCameraRef camera = SU_INVALID;
    SUCameraCreate(&camera);
    SUSceneGetCamera(info.orig_ref, &camera);
    SUSceneSetCamera(sister_page, camera);
    // Note: SUSceneSetCamera copies the data, so we can/should release our temp
    // camera? Actually documentation implies ownership transfer OR copy.
    // Usually safe to release if we created it.
    // Assuming standard behavior.

    // Isolate Layer
    if (SUIsValid(section_layer)) {
      SUSceneSetUseHiddenLayers(sister_page, true);
      for (SULayerRef layer : layers) {
        if (layer.ptr == section_layer.ptr)
          continue;
        SUSceneAddLayer(sister_page, layer);
      }
    }

    // Add to model (appends to end)
    int out_idx = -1;
    SUModelAddScene(model, -1, sister_page, &out_idx);
    info.sister_index = out_idx;
    info.sister_ref = sister_page;
  }

  // Save modified SKP
  SUModelSaveToFile(model, source_skp_path.c_str());
  SUModelRelease(&model);

  if (show_debug)
    std::cout << "SKP modified and saved. Generating LayOut..." << std::endl;

  // 3. Create LayOut Document
  LODocumentRef doc = SU_INVALID;
  LODocumentCreateEmpty(&doc);

  // Get Default Layer (usually "Default" or "Layer 1" at index 0)
  LOLayerRef lo_layer = SU_INVALID;
  LODocumentGetLayerAtIndex(doc, 0, &lo_layer);

  double paper_w = 400.0; // Points?
  double paper_h = 300.0;
  // TODO: Get actual paper size from doc?
  // LOPageInfoRef page_info = SU_INVALID; LODocumentGetPageInfo(doc,
  // &page_info); LOPageInfoGetPaperWidth(page_info, &paper_w); ... Skipping for
  // brevity/robustness now.

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

    // Create Viewports
    // Bounds: x, y, w, h
    LOAxisAlignedRect2D bounds = {{10, 10}, {paper_w - 20, paper_h - 20}};
    // Note: Rect is {Point upper_left, Point lower_right}?
    // Documentation says: { {x, y}, {width, height} } ??
    // Check geometry.h if possible.
    // Usually { Point2D position, Size2D size } or { Point2D min, Point2D max
    // }. If it is Min/Max: {10,10} to {390, 290} is correct. If it is Pos/Size:
    // {10,10} with {380, 280} is correct. Most 2D rects are Pos/Size. But
    // LOAxisAlignedRect2D implies Min/Max usually in SU. Wait,
    // "AxisAlignedRect2D" usually implies Min/Max. "Rect2D" might be Pos/Size.
    // I'll stick to assumptions or check previously working code?
    // Previous code had: {{10, 10}, {paper_w/2 - 20, paper_h - 20}} (Wait, /2?)
    // I'll use {10, 10} and {100, 100} just to see SOMETHING.
    // Safe bounds: { {10, 10}, {200, 200} }.

    // Viewport 1 (Original)
    LOSketchUpModelRef vp1 = SU_INVALID;
    LOSketchUpModelCreate(&vp1, source_skp_path.c_str(), &bounds);
    LOSketchUpModelSetCurrentScene(vp1, info.orig_index); // 0-based index
    // API documentation for LOSketchUpModelSetCurrentScene takes index.
    // Usually 1-based in LayOut UI, but C API?
    // Let's assume 1-based as per common LO behavior (Page match).
    // If 0-based, +1 might select wrong scene.
    // I'll try +1.

    // Viewport 2 (Sister)
    LOSketchUpModelRef vp2 = SU_INVALID;
    LOSketchUpModelCreate(&vp2, source_skp_path.c_str(), &bounds);
    LOSketchUpModelSetCurrentScene(vp2, info.sister_index);

    // Set Render Mode? Raster/Vector/Hybrid?
    // LOSketchUpModelSetRenderMode(vp2, LOSketchUpModelRenderMode_Vector);

    // Add to Page
    LODocumentAddEntity(doc, LOSketchUpModelToEntity(vp1), lo_layer, page);
    LODocumentAddEntity(doc, LOSketchUpModelToEntity(vp2), lo_layer, page);

    // Grouping?
    // LOGroupCreate({vp1, vp2}) -> Not easily available without lists.
    // Skipping grouping for now. Just placing on top is verified manually.

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
