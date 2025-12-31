#include <cmath>
#include <fstream>
#include <iostream>
#include <stdio.h>
#include <string>
#include <vector>

#include "skalp_convert.h"
#include "sketchup.h"
#include <LayOutAPI/layout.h>
#include <LayOutAPI/model/style.h>
#include <SketchUpAPI/common.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/model.h>

/**
 * Extracts line geometry from a LayOut Path Entity.
 * Used to convert vector-rendered section lines back into raw coordinates.
 */
hiddenlines get_lines_from_path(LOEntityRef entity_ref, double scale,
                                double reflected,
                                hiddenlines hiddenline_result) {

  LOEntityType entity_type;
  LOEntityGetEntityType(entity_ref, &entity_type);

  LOStyleRef style = SU_INVALID;
  LOStyleCreate(&style);
  LOEntityGetStyle(entity_ref, style);

  // check line weight to see if it's a sectionline (Skalp convention?)
  double stroke_width;
  SUColor stroke_color;

  LOStyleGetStrokeWidth(style, &stroke_width);
  LOStyleGetStrokeColor(style, &stroke_color);
  LOStyleRelease(&style);

  if ((entity_type == LOEntityType_Path) && (stroke_width < 10.0)) {

    LOPathRef path = LOPathFromEntity(entity_ref);
    bool is_closed;

    LOPathGetClosed(path, &is_closed);

    if (!is_closed) {
      size_t num_points = 0;
      size_t exact_num_points;

      LOPathGetNumberOfPoints(path, &num_points);

      if (num_points > 0) {
        std::vector<LOPoint2D> path_points(num_points);
        LOPathGetPoints(path, num_points, &path_points[0], &exact_num_points);

        for (size_t m = 0; m < (exact_num_points - 1); ++m) {
          line newline;
          newline.layer_index_R = stroke_color.red;
          newline.layer_index_G = stroke_color.green;
          newline.layer_index_B = stroke_color.blue;

          hiddenline_result.lines.push_back(newline);

          // Apply projection/reflection logic
          // Note: LayOut coordinates are Paper space. Skalp converts them back
          // to Model space equivalents? "reflected" parameter suggests handling
          // rear view mirroring.

          hiddenline_result.lines.back().startpoint.x =
              round((path_points[m].x / scale * reflected) * 100.0) / 100.0;
          hiddenline_result.lines.back().startpoint.y =
              round((path_points[m].y / scale * -1) * 100.0) / 100.0;

          hiddenline_result.lines.back().endpoint.x =
              round((path_points[m + 1].x / scale * reflected) * 100.0) / 100.0;
          hiddenline_result.lines.back().endpoint.y =
              round((path_points[m + 1].y / scale * -1) * 100.0) / 100.0;
        }
      }
    }
  }
  return hiddenline_result;
}

/**
 * Main logic to calculate "Hidden Line" geometry using LayOut API's Vector
 * Rendering.
 *
 * Process:
 * 1. Creates a temporary LayOut document.
 * 2. Inserts the SketchUp model.
 * 3. Applies Vector Rendering (which calculates hidden lines).
 * 4. "Explodes" the rendered view into raw line entities.
 * 5. Extracts coordinates from these lines.
 */
std::vector<hiddenlines> get_exploded_entities(
    std::string path, double height, std::vector<int> page_index_array,
    std::vector<double> scale_array, std::vector<bool> perspective_array,
    std::vector<SUPoint3D> target_array, double reflected) {

  std::vector<hiddenlines> hiddenline_result;

  // Local resources - MUST NOT be static to allow re-entrancy/proper cleanup
  LODocumentRef lo_document_ref = SU_INVALID;
  LOSketchUpModelRef lo_model_ref = SU_INVALID;
  std::string file_path;

  // Initialize both APIs
  LOInitialize();
  SUInitialize(); // Model creation might need SUInitialize if using SU logic,
                  // though LO handles internal SU model? Actually LO API
                  // handles LO Refs. SU API handles SUModelRef. Code below
                  // creates an SUModelRef too.

  SUResult result;

  // --- Create LayOut Model ---
  LOAxisAlignedRect2D bounds = {{0., 0.}, {200., height}};

  result = LOSketchUpModelCreate(&lo_model_ref, path.c_str(), &bounds);

  if (result != SU_ERROR_NONE) {
    // Failed to load model into LayOut
    LOTerminate();
    SUTerminate();
    return hiddenline_result;
  }

  // --- Create SU Model (for Scenes lookup?) ---
  // The code creates an SUModelRef to match Scene Indices?
  // LayOut API also handles Scenes.
  // Wait, the code creates SUModelRef just to... "Get correct scene"?
  // But calls LOSketchUpModelSetCurrentScene with `page_index_array[j] + 1`?
  // It seems SUModelRef is not strictly used for logic here except...
  // Ah, the code creates SUModel from file, does `init` logic?
  // Actually, the previous code loaded it but didn't seem to use it except for
  // one thing: It didn't use it! It assigned `model = SU_INVALID`, loaded it,
  // then `SUModelRelease` at end? Wait, lines 140-151 in original: Calls
  // `SUModelCreateFromFileWithStatus`. Then `file_path` extraction. Then
  // `entity_ref = LOSketchUpModelToEntity`. The `SUModelRef model` variable
  // seems COMPLETELY UNUSED except for loading and releasing. CHECK: Does
  // `SUModelCreateFromFile` have side effects needed? No. Does it check if file
  // is valid? LO does that too. I will KEEP it to be safe (maybe file lock
  // checks?), but comment it seems redundant. Actually, I'll remove it if it's
  // truly unused to speed things up. Scanning code... `model` is not passed to
  // LO functions. `path` is passed to LO. I'll keep the path extraction logic
  // but remove the SUModel load if possible. Wait, strict adherence to
  // refactoring: preserve behavior. I'll Load and Release.

  SUModelRef model = SU_INVALID;
  SUModelLoadStatus status;
  result = SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);

  // Ignore result? Original didn't exit on SUModel failure, only LO failure
  // comments?

  size_t path_end = path.find_last_of("\\/");
  if (path_end != std::string::npos)
    file_path = path.substr(0, path_end + 1);

  // --- Setup LayOut Document ---
  LOEntityRef entity_ref = LOSketchUpModelToEntity(lo_model_ref);

  result = LODocumentCreateEmpty(&lo_document_ref);
  if (SU_ERROR_NONE != result) {
    if (SUIsValid(model))
      SUModelRelease(&model); // Check if we need to release SU model
    LOSketchUpModelRelease(&lo_model_ref);
    LOTerminate();
    SUTerminate();
    return hiddenline_result;
  }

  LOPageInfoRef page_info = SU_INVALID;
  result = LODocumentGetPageInfo(lo_document_ref, &page_info);

  // Set Page Size large enough
  if (SU_ERROR_NONE == result) {
    LOPageInfoSetHeight(page_info, 200.0);
    LOPageInfoSetWidth(page_info, 200.0);
  }

  // Set Vector rendering
  result = LOSketchUpModelSetRenderMode(lo_model_ref,
                                        LOSketchUpModelRenderMode_Vector);

  // Add entity to doc
  result = LODocumentAddEntityUsingIndexes(lo_document_ref, entity_ref, 0, 0);

  if (SU_ERROR_NONE != result) {
    if (SUIsValid(model))
      SUModelRelease(&model);
    LOSketchUpModelRelease(&lo_model_ref);
    LODocumentRelease(&lo_document_ref);
    LOTerminate();
    SUTerminate();
    return hiddenline_result;
  }

  // Set output lineweight
  result = LOSketchUpModelSetLineWeight(lo_model_ref, 1.0);

  size_t total_scenes = page_index_array.size();

  for (size_t j = 0; j < total_scenes; ++j) {
    // Progress Report
    std::cout << "*P*" << j << "|" << total_scenes << "|"
              << "Processing rear lines"
              << "|" << std::to_string(page_index_array[j]) << std::endl;

    hiddenline_result.push_back(hiddenlines());

    // Set Scene (1-based index for LO?)
    result =
        LOSketchUpModelSetCurrentScene(lo_model_ref, page_index_array[j] + 1);

    if (SU_ERROR_NONE != result) {
      std::cerr
          << "[C++] ERROR: LOSketchUpModelSetCurrentScene failed for index: "
          << page_index_array[j] << " code: " << result << std::endl;
      break;
    } else {
      std::cerr << "[C++] Layout switched to scene index: "
                << page_index_array[j] + 1 << std::endl;
    }

    double current_scale = scale_array[j];
    if (!perspective_array[j] && current_scale > 0) {
      LOSketchUpModelSetScale(lo_model_ref, current_scale);
    } else if (!perspective_array[j]) {
      LOSketchUpModelGetScale(lo_model_ref, &current_scale);
    }

    // Explode
    LOEntityListRef exploded_entity_list = SU_INVALID;
    LOEntityListCreate(&exploded_entity_list);

    result =
        LOSketchUpModelGetExplodedEntities(lo_model_ref, exploded_entity_list);

    if (SU_ERROR_NONE == result) {
      // Retrieve result (Group)
      LOEntityRef exploded_entity = SU_INVALID;
      LOEntityListGetEntityAtIndex(exploded_entity_list, 0, &exploded_entity);

      // Process geometry
      LOEntityType exploded_entity_type;
      LOEntityGetEntityType(exploded_entity, &exploded_entity_type);

      hiddenline_result[j].index = page_index_array[j];

      if (exploded_entity_type == LOEntityType_Group) {

        LOGroupRef exploded_group = LOGroupFromEntity(exploded_entity);
        size_t exploded_group_number_of_entities;
        LOGroupGetNumberOfEntities(exploded_group,
                                   &exploded_group_number_of_entities);

        // Calc 2D translation offset
        LOPoint3D lo_point3D = {target_array[j].x, target_array[j].y,
                                target_array[j].z}; // Convert types
        LOPoint2D target_2d;
        LOSketchUpModelConvertModelPointToPaperPoint(lo_model_ref, &lo_point3D,
                                                     &target_2d);

        hiddenline_result[j].target_point.x =
            round((target_2d.x / current_scale * reflected) * 100.0) / 100.0;
        hiddenline_result[j].target_point.y =
            round((target_2d.y / current_scale * -1) * 100.0) / 100.0;

        // Iterate exploded lines
        for (size_t k = 0; k < exploded_group_number_of_entities; ++k) {
          LOEntityRef profile_lines = SU_INVALID;
          LOGroupGetEntityAtIndex(exploded_group, k, &profile_lines);

          LOEntityType p_type;
          LOEntityGetEntityType(profile_lines, &p_type);

          if (p_type == LOEntityType_Path) {
            hiddenline_result[j] = get_lines_from_path(
                profile_lines, current_scale, reflected, hiddenline_result[j]);
          } else if (p_type == LOEntityType_Group) {
            LOGroupRef sub_group = LOGroupFromEntity(profile_lines);
            size_t sub_count;
            LOGroupGetNumberOfEntities(sub_group, &sub_count);

            for (size_t m = 0; m < sub_count; ++m) {
              LOEntityRef sub_ent = SU_INVALID;
              LOGroupGetEntityAtIndex(sub_group, m, &sub_ent);

              if (SUIsValid(sub_ent)) {
                hiddenline_result[j] = get_lines_from_path(
                    sub_ent, current_scale, reflected, hiddenline_result[j]);
              }
            }
          }
        }
      }
    }

    // Always release entity list per loop
    LOEntityListRelease(&exploded_entity_list);
  }

  // Debug/Test output    // SAVE LAYOUT ONLY FOR TESTING IF NEEDED
  // Force save to Desktop to be sure
  std::string lo_filepath = "/Users/guywydouw/Desktop/CreatedFromRuby.layout";
  LODocumentSaveToFile(lo_document_ref, lo_filepath.c_str(),
                       LODocumentVersion_Current);

  // Final Cleanup
  if (SUIsValid(model))
    SUModelRelease(&model);

  LOSketchUpModelRelease(&lo_model_ref);
  LODocumentRelease(&lo_document_ref);

  LOTerminate();
  SUTerminate();

  return hiddenline_result;
}
