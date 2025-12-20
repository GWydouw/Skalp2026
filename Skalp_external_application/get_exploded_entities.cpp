#include <stdio.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cmath>

#include <LayOutAPI/layout.h>
#include <LayOutAPI/model/style.h>
#include <SketchUpAPI/initialize.h>
#include <SketchUpAPI/common.h>
#include <SketchUpAPI/model/model.h>
#include "skalp_convert.h"

//void debug_time(std::string debug_text);
void debug_info(std::string debug_text);

hiddenlines get_lines_from_path(LOEntityRef entity_ref, double scale, double reflected, hiddenlines hiddenline_result){
    
    LOEntityType entity_type;
    LOEntityGetEntityType(entity_ref, &entity_type);
    
    LOStyleRef style = SU_INVALID;
    LOStyleCreate(&style);
    LOEntityGetStyle(entity_ref, style);
    
    // check is lineweight to see if it's a sectionline
    double stroke_width;
    SUColor stroke_color;
    
    LOStyleGetStrokeWidth(style, &stroke_width);
    LOStyleGetStrokeColor(style, &stroke_color);
    LOStyleRelease(&style);
    
    if ((entity_type == LOEntityType_Path) && (stroke_width < 10.0) ){
        
        LOPathRef path = LOPathFromEntity(entity_ref);
        bool is_closed;
        
        LOPathGetClosed(path, &is_closed);
        
        if (!is_closed) {
            size_t num_points = 0;
            size_t exact_num_points;
            
            LOPathGetNumberOfPoints(path, &num_points);
            std::vector<LOPoint2D> path_points(num_points);
            LOPathGetPoints(path, num_points, &path_points[0], &exact_num_points);
            
            //long n = hiddenline_result[j].lines.size();
            
            for (size_t m = 0; m < (exact_num_points - 1); ++m){
                line newline;
                newline.layer_index_R = stroke_color.red;
                newline.layer_index_G = stroke_color.green;
                newline.layer_index_B = stroke_color.blue;
                
                hiddenline_result.lines.push_back(newline);
                
                hiddenline_result.lines.back().startpoint.x = round((path_points[m].x / scale * reflected)*100.0)/100.0;
                hiddenline_result.lines.back().startpoint.y = round((path_points[m].y / scale * -1)*100.0)/100.0;
                
                hiddenline_result.lines.back().endpoint.x = round((path_points[m+1].x / scale * reflected)*100.0)/100.0;
                hiddenline_result.lines.back().endpoint.y = round((path_points[m+1].y / scale * -1)*100.0)/100.0;
            }
        }
    }
    return hiddenline_result;
}

std::vector<hiddenlines> get_exploded_entities(std::string path, double height, std::vector<int> page_index_array, std::vector<double> scale_array, std::vector<bool> perspective_array, std::vector<SUPoint3D> target_array, double reflected) {

    //debug_time("get_exploded_entities");
    
    std::vector<hiddenlines> hiddenline_result;
    
    static LODocumentRef lo_document_ref;
    static LOSketchUpModelRef lo_model_ref;
    static std::string file_path;

    LOInitialize();
    SUResult result;
    LOEntityRef entity_ref = SU_INVALID;
    
    SUSetInvalid(lo_document_ref);
    SUSetInvalid(lo_model_ref);
    
    // Load the SketchUp model.
    LOAxisAlignedRect2D bounds = {{0.,0.}, {200.,height}};
    //debug_time("BEFORE create layout");

    result = LOSketchUpModelCreate(&lo_model_ref, path.c_str(), &bounds);

/*
    if (SU_ERROR_NO_DATA == result) {
        debug_info("SU_ERROR_NO_DATA");
    }
    if (SU_ERROR_NULL_POINTER_OUTPUT  == result) {
        debug_info("SU_ERROR_NULL_POINTER_OUTPUT ");
    }
    if (SU_ERROR_OVERWRITE_VALID == result) {
        debug_info("SU_ERROR_OVERWRITE_VALID");
    }
    if (SU_ERROR_NULL_POINTER_INPUT == result) {
        debug_info("SU_ERROR_NULL_POINTER_INPUT");
    }
    if (SU_ERROR_OUT_OF_RANGE == result) {
        debug_info("SU_ERROR_OUT_OF_RANGE");
    }
    if (SU_ERROR_SERIALIZATION == result) {
        debug_info("SU_ERROR_SERIALIZATION");
    }
    
    if (SU_ERROR_NONE != result) {
        LOTerminate();
        return hiddenline_result;
    }
*/
    
    //debug_time("AFTER create layout");
    // Set rendermode to vector
    //LOSketchUpModelSetRenderMode(lo_model_ref, LOSketchUpModelRenderMode_Vector );
    //LOSketchUpModelSetRenderMode(lo_model_ref, LOSketchUpModelRenderMode_Raster );
    
    //SU model
    SUInitialize();
    SUModelRef model = SU_INVALID;
    //debug_time("BEFORE Create model from file");
    
    SUModelLoadStatus status;
    result = SUModelCreateFromFileWithStatus(&model, path.c_str(), &status);
    
    //debug_time("AFTER Create model from file");
    
    size_t path_end = path.find_last_of("\\/");
    if (path_end != std::string::npos)
        file_path = path.substr(0, path_end + 1);
    
    // Get correct scene
    
    // Convert the model ref to an entity ref for adding to the LayOut document.
    entity_ref = LOSketchUpModelToEntity(lo_model_ref);
    
    
    // Create a new LayOut document.
    result = LODocumentCreateEmpty(&lo_document_ref);
    if (SU_ERROR_NONE != result) {
        LOSketchUpModelRelease(&lo_model_ref);
        LOTerminate();
        return hiddenline_result;
    }
    
    //debug_time("Create new empty layout");
    
    LOPageInfoRef page_info = SU_INVALID;
    result = LODocumentGetPageInfo(lo_document_ref, &page_info);
    
    if (SU_ERROR_NONE != result) {
        LOSketchUpModelRelease(&lo_model_ref);
        LOTerminate();
        return hiddenline_result;
    }
    
    //max size 200 x 200 inch
    
    LOPageInfoSetHeight(page_info, 200.0);
    LOPageInfoSetWidth(page_info, 200.0);
    
    result = LOSketchUpModelSetRenderMode(lo_model_ref, LOSketchUpModelRenderMode_Vector );
    //result = LOSketchUpModelRender(lo_model_ref);
    
    // Add the SketchUp model to the document on the default layer on the first page.
    result = LODocumentAddEntityUsingIndexes(lo_document_ref, entity_ref, 0, 0);

    //debug_time("Add Model to layout");
    
    if (SU_ERROR_NONE != result) {
        LOSketchUpModelRelease(&lo_model_ref);
        LODocumentRelease(&lo_document_ref);
        LOTerminate();
        return hiddenline_result;
    }
    
    // Initially, the model should need to be rendered.
    //bool render_needed = false;
    //LOSketchUpModelIsRenderNeeded(lo_model_ref, &render_needed);
    
    // Render if needed.
    //if (render_needed)
    
    //debug_time("Set Model to vector");
    
    //Set Model LineWeight
    result = LOSketchUpModelSetLineWeight(lo_model_ref, 1.0);
    
    if (SU_ERROR_NONE != result) {
        LOSketchUpModelRelease(&lo_model_ref);
        LODocumentRelease(&lo_document_ref);
        LOTerminate();
        return hiddenline_result;
    }
    
    std::vector<double> result_array;
    
    size_t i = page_index_array.size();
    
    for (size_t j = 0; j < i; ++j) {
        
        hiddenline_result.push_back(hiddenlines());
        
        // set correct scene
        result = LOSketchUpModelSetCurrentScene(lo_model_ref, page_index_array[j] + 1);
        
        if (SU_ERROR_NONE != result) {
            LOSketchUpModelRelease(&lo_model_ref);
            LODocumentRelease(&lo_document_ref);
            LOTerminate();
            return hiddenline_result;
        }
        
        // Get model scale
        double scale;
        
        if (perspective_array[j]) {
            scale = scale_array[j];
            
        }
        else
        {
            LOSketchUpModelGetScale(lo_model_ref, &scale);
        };
        
        // Get exploded entities
        LOEntityListRef exploded_entity_list = SU_INVALID;
        LOEntityListCreate(&exploded_entity_list);
        result = LOSketchUpModelGetExplodedEntities(lo_model_ref, exploded_entity_list);
        
        //debug_time("explode");
        
        if (SU_ERROR_NONE != result) {
            LOEntityListRelease(&exploded_entity_list);
            LOSketchUpModelRelease(&lo_model_ref);
            LODocumentRelease(&lo_document_ref);
            LOTerminate();
            return hiddenline_result;
        }
        
        size_t num_exploded_entities;
        LOEntityListGetNumberOfEntities(exploded_entity_list, &num_exploded_entities);
        
        LOEntityRef exploded_entity = SU_INVALID;
        result = LOEntityListGetEntityAtIndex(exploded_entity_list, 0, &exploded_entity);
        
        if (SU_ERROR_NONE != result) {
            LOEntityListRelease(&exploded_entity_list);
            LOSketchUpModelRelease(&lo_model_ref);
            LODocumentRelease(&lo_document_ref);
            LOTerminate();
            return hiddenline_result;
        }
        
        // get entity type of exploded entity
        LOEntityType exploded_entity_type;
        LOEntityGetEntityType(exploded_entity, &exploded_entity_type);
        
        //explode lines array
        hiddenline_result[j].index = page_index_array[j];
        
        if (exploded_entity_type == LOEntityType_Group){
            
            LOGroupRef exploded_group = LOGroupFromEntity(exploded_entity);
            size_t exploded_group_number_of_entities;
            LOGroupGetNumberOfEntities(exploded_group, &exploded_group_number_of_entities);
            
            // find translation between 3d and 2d
            LOPoint3D lo_point3D = target_array[j];
            LOPoint2D target_2d;
            result = LOSketchUpModelConvertModelPointToPaperPoint(lo_model_ref, &lo_point3D, &target_2d);
            
            double target_x = round((target_2d.x / scale * reflected)*100.0)/100.0;
            double target_y = round((target_2d.y / scale * -1)*100.0)/100.0;
            
            hiddenline_result[j].target_point.x = target_x;
            hiddenline_result[j].target_point.y = target_y;
            
            if (SU_ERROR_NONE != result) {
                LOEntityListRelease(&exploded_entity_list);
                LOSketchUpModelRelease(&lo_model_ref);
                LODocumentRelease(&lo_document_ref);
                LOTerminate();
                return hiddenline_result;
            }
            
            
            for (size_t num_groups = 0; num_groups < exploded_group_number_of_entities; ++num_groups){
                LOEntityRef profile_lines = SU_INVALID;
                LOGroupGetEntityAtIndex(exploded_group, num_groups, &profile_lines);
                
                LOEntityType profile_lines_entity_type;
                LOEntityGetEntityType(profile_lines, &profile_lines_entity_type);
                
                if (profile_lines_entity_type == LOEntityType_Path){
                    hiddenline_result[j] = get_lines_from_path(profile_lines, scale, reflected, hiddenline_result[j]);
                }else if (profile_lines_entity_type == LOEntityType_Group){
                    LOGroupRef profile_lines_group = LOGroupFromEntity(profile_lines);
                    
                    size_t profile_lines_number_of_entities;
                    LOGroupGetNumberOfEntities(profile_lines_group, &profile_lines_number_of_entities);
                    
                    for (size_t k = 0; k < profile_lines_number_of_entities; ++k) {
                        
                        LOEntityRef entity_ref = SU_INVALID;
                        LOGroupGetEntityAtIndex(profile_lines_group, k, &entity_ref);
                        
                        if (!SUIsInvalid(entity_ref)){
                            hiddenline_result[j] = get_lines_from_path(entity_ref, scale, reflected, hiddenline_result[j]);
                        }
                    }
                }
            }
            SUSetInvalid(entity_ref);
            SUSetInvalid(exploded_entity);
        };
        
        // SAVE LAYOUT ONLY FOR TESTING IF NEEDED
        std::string lo_filepath = file_path + "CreatedFromRuby.layout";
        LODocumentSaveToFile(lo_document_ref, lo_filepath.c_str(), LODocumentVersion_Current);
        
        LOEntityListRelease(&exploded_entity_list);
    }
    
    // Release our references and return success.
    LOSketchUpModelRelease(&lo_model_ref);
    LODocumentRelease(&lo_document_ref);
    LOTerminate();
    
    return hiddenline_result;
}
