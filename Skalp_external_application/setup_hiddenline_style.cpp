#include <stdio.h>
#include <string>
#include <vector>
#include <iostream>
#include <fstream>

#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/model/model.h>
#include <SketchUpAPI/model/scene.h>
#include <SketchUpAPI/model/typed_value.h>
#include <SketchUpAPI/model/rendering_options.h>
#include <SketchUpAPI/model/styles.h>

bool modifyStyle(std::string path, std::string new_path) {

    // Always initialize the API before using it
    SUInitialize();

    // Load the model from a file
    SUModelRef model = SU_INVALID;

    // Load the SketchUp model.

    SUModelLoadStatus status;
    SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);

    SUStylesRef styles = SU_INVALID;
    SUModelGetStyles(model, &styles);
    SUStyleRef style = SU_INVALID;
    SUStylesGetActiveStyle(styles, &style);

    SURenderingOptionsRef rendering_options = SU_INVALID;
    SUModelGetRenderingOptions(model, &rendering_options);

    SUTypedValueRef off_bool = SU_INVALID;
    SUTypedValueCreate(&off_bool);
    SUTypedValueSetBool(off_bool, false);

    SURenderingOptionsSetValue(rendering_options, "SectionCutFilled", off_bool);
    SURenderingOptionsSetValue(rendering_options, "SectionCutDrawEdges", off_bool);

    // Save the in-memory model to a file
    SUModelSaveToFile(model, new_path.c_str());
    // Must release the model or there will be memory leaks
    SUTypedValueRelease(&off_bool);
    SUModelRelease(&model);
    // Always terminate the API when done using it
    SUTerminate();
    return true;
}

bool hiddenline_rendering_options(SURenderingOptionsRef rendering_options){
    
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
    SUTypedValueSetInt32(width, 1);
    SUTypedValueSetInt32(edge_color_mode, 0);
    
    SURenderingOptionsSetValue(rendering_options, "EdgeDisplayMode", on_bool);
    SURenderingOptionsSetValue(rendering_options, "DrawSilhouettes", on_bool);
    SURenderingOptionsSetValue(rendering_options, "DrawDepthQue", off_bool);
    SURenderingOptionsSetValue(rendering_options, "DrawLineEnds", off_bool);
    SURenderingOptionsSetValue(rendering_options, "JitterEdges", off_bool);
    SURenderingOptionsSetValue(rendering_options, "ExtendLines", off_bool);
    
    SURenderingOptionsSetValue(rendering_options, "SilhouetteWidth", width);
    SURenderingOptionsSetValue(rendering_options, "DepthQueWidth", width);
    SURenderingOptionsSetValue(rendering_options, "LineExtension", width);
    SURenderingOptionsSetValue(rendering_options, "LineEndWidth", width);
    
    SURenderingOptionsSetValue(rendering_options, "DisplayText", off_bool);
    SURenderingOptionsSetValue(rendering_options, "SectionCutWidth", width);
    
    SURenderingOptionsSetValue(rendering_options, "EdgeColorMode", edge_color_mode);
    SURenderingOptionsSetValue(rendering_options, "DisplayColorByLayer", colorbylayer_mode);
    
    SUTypedValueRelease(&on_bool);
    SUTypedValueRelease(&off_bool);
    SUTypedValueRelease(&width);
    
    return true;
}


bool setup_hiddenline_style(std::string path){
    
    // Always initialize the API before using it
    SUInitialize();
    
    // Load the model from a file
    SUModelRef model = SU_INVALID;
    
    // Load the SketchUp model.
    
    SUModelLoadStatus status;
    SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);
    
    size_t num_scenes;
    size_t count;
    
    SUModelGetNumScenes(model, &num_scenes);
    std::vector<SUSceneRef> scenes(num_scenes);
    
    for (size_t i = 0; i < num_scenes; ++i) {
        SUSetInvalid(scenes[i]);
    }
    
    SUModelGetScenes(model, num_scenes, &scenes[0], &count);
    
    for (size_t i = 0; i < num_scenes; ++i) {
        
        SURenderingOptionsRef options = SU_INVALID;
        SUSceneGetRenderingOptions(scenes[i], &options);
        hiddenline_rendering_options(options);
        SUSceneSetUseRenderingOptions(scenes[i], true);
    }
    
    // Save the in-memory model to a file
    SUModelSaveToFile(model, path.c_str());
    // Must release the model or there will be memory leaks
    SUModelRelease(&model);
    // Always terminate the API when done using it
    SUTerminate();
    return true;
}
