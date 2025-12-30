#include <fstream>
#include <iostream>
#include <stdio.h>
#include <string>
#include <vector>

#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/rendering_options.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/styles.h>
#include <SketchUpAPI/model/typed_value.h>

/**
 * Modifies the style of a model to disable section cuts.
 * Used for exporting purposes where section cuts shouldn't run.
 */
bool modifyStyle(std::string path, std::string new_path) {

  SUInitialize();

  SUModelRef model = SU_INVALID;
  SUModelLoadStatus status;
  SUResult result =
      SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);

  if (result != SU_ERROR_NONE) {
    SUTerminate();
    return false;
  }

  // Is getting styles/active style needed? The code gets rendering options from
  // MODEL. SUModelGetRenderingOptions returns the active view's options.
  SURenderingOptionsRef rendering_options = SU_INVALID;
  SUModelGetRenderingOptions(model, &rendering_options);

  SUTypedValueRef off_bool = SU_INVALID;
  SUTypedValueCreate(&off_bool);
  SUTypedValueSetBool(off_bool, false);

  // Disable Section Cuts for export
  SURenderingOptionsSetValue(rendering_options, "SectionCutFilled", off_bool);
  SURenderingOptionsSetValue(rendering_options, "SectionCutDrawEdges",
                             off_bool);

  result = SUModelSaveToFile(model, new_path.c_str());

  // Cleanup
  SUTypedValueRelease(&off_bool);
  SUModelRelease(&model);
  SUTerminate();

  return (result == SU_ERROR_NONE);
}

/**
 * Applies the standard "Hidden Line" rendering options to a given options set.
 */
bool hiddenline_rendering_options(SURenderingOptionsRef rendering_options) {

  SUTypedValueRef on_bool = SU_INVALID;
  SUTypedValueRef off_bool = SU_INVALID;
  SUTypedValueRef width = SU_INVALID;
  SUTypedValueRef edge_color_mode = SU_INVALID;
  SUTypedValueRef colorbylayer_mode = SU_INVALID;

  SUTypedValueCreate(&on_bool);
  SUTypedValueCreate(&off_bool);
  SUTypedValueCreate(&width);
  SUTypedValueCreate(&edge_color_mode);
  SUTypedValueCreate(&colorbylayer_mode);

  SUTypedValueSetBool(on_bool, true);
  SUTypedValueSetBool(off_bool, false);
  SUTypedValueSetBool(colorbylayer_mode, true);

  // Widths are usually integers
  SUTypedValueSetInt32(width, 1);

  // EdgeColorMode: 0 = Object Color (or Black?)
  SUTypedValueSetInt32(edge_color_mode, 0);

  // Booleans
  SURenderingOptionsSetValue(rendering_options, "EdgeDisplayMode", on_bool);
  SURenderingOptionsSetValue(rendering_options, "DrawSilhouettes", on_bool);
  SURenderingOptionsSetValue(rendering_options, "DrawDepthQue", off_bool);
  SURenderingOptionsSetValue(rendering_options, "DrawLineEnds", off_bool);
  SURenderingOptionsSetValue(rendering_options, "JitterEdges", off_bool);
  SURenderingOptionsSetValue(rendering_options, "ExtendLines", off_bool);

  SURenderingOptionsSetValue(rendering_options, "DisplayText", off_bool);

  // Integers / Widths
  SURenderingOptionsSetValue(rendering_options, "SilhouetteWidth",
                             width); // Often 3 is default, but here 1
  SURenderingOptionsSetValue(rendering_options, "DepthQueWidth", width);
  SURenderingOptionsSetValue(rendering_options, "LineExtension", width);
  SURenderingOptionsSetValue(rendering_options, "LineEndWidth", width);

  // Check type for SectionCutWidth (usually int)
  SURenderingOptionsSetValue(rendering_options, "SectionCutWidth", width);

  // Edge Color modes
  SURenderingOptionsSetValue(rendering_options, "EdgeColorMode",
                             edge_color_mode);
  SURenderingOptionsSetValue(rendering_options, "DisplayColorByLayer",
                             colorbylayer_mode);

  // Cleanup ALL values
  SUTypedValueRelease(&on_bool);
  SUTypedValueRelease(&off_bool);
  SUTypedValueRelease(&width);
  SUTypedValueRelease(&edge_color_mode);
  SUTypedValueRelease(&colorbylayer_mode);

  return true;
}

/**
 * Sets up Hidden Line styles for ALL scenes in the model.
 * Used to prepare a model for hidden-line calculation.
 */
bool setup_hiddenline_style(std::string path) {

  SUInitialize();

  SUModelRef model = SU_INVALID;
  SUModelLoadStatus status;
  SUResult result =
      SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);

  if (result != SU_ERROR_NONE) {
    SUTerminate();
    return false;
  }

  size_t num_scenes = 0;
  size_t count = 0;
  SUModelGetNumScenes(model, &num_scenes);

  if (num_scenes > 0) {
    std::vector<SUSceneRef> scenes(num_scenes);
    for (size_t i = 0; i < num_scenes; ++i)
      SUSetInvalid(scenes[i]);

    SUModelGetScenes(model, num_scenes, &scenes[0], &count);

    for (size_t i = 0; i < num_scenes; ++i) {
      SURenderingOptionsRef options = SU_INVALID;
      SUSceneGetRenderingOptions(scenes[i], &options);

      // Apply settings
      hiddenline_rendering_options(options);

      // Force scene to USE these options
      SUSceneSetUseRenderingOptions(scenes[i], true);
    }
  }

  result = SUModelSaveToFile(model, path.c_str());

  SUModelRelease(&model);
  SUTerminate();

  return (result == SU_ERROR_NONE);
}
