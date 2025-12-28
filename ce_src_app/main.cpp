#include <vector>
#include <iostream>
#include <fstream>
#include <string>
#include <cstdio>

#include "skalp_convert.h"
#include "sketchup.h"

#include "base64/base64.h"

#ifdef _WIN32
bool OS_WIN = true;
#else
bool OS_WIN = false;
#endif

std::string error_string;

/*
void debug_time(std::string text);
auto start = std::chrono::system_clock::now();
auto end = std::chrono::system_clock::now();
std::chrono::duration<double> elapsed_seconds;

void debug_time(std::string debug_text){

    end = std::chrono::system_clock::now();
    elapsed_seconds = end-start;
    std::cout << "*D*" << debug_text << " - " << elapsed_seconds.count()  << std::endl;
    start = end;
};
*/

void debug_info(std::string debug_text){
    std::cout << "*D*" << debug_text << std::endl;
};


SUEntitiesRef get_sectiongroups(SUEntitiesRef entities);
bool remove_materials(SUModelRef model);
bool create_layer_materials(std::string path, std::vector<std::string> layer_names);
bool setup_hiddenline_style(std::string path);
bool modifyStyle(std::string path, std::string new_path);
bool create_white_model(std::string path, std::string fase, SUMaterialRef color_material);
bool setup_reversed_scene(std::string path, std::string new_path, std::vector<int> page_index_array,  std::vector<SUPoint3D> eye_array, std::vector<SUPoint3D> target_array, std::vector<SUTransformation> transformation_array, std::vector<std::string> id_array, std::vector<SUVector3D> up_vector_array,  double  bounds);
std::vector<hiddenlines> get_exploded_entities(std::string path, double height, std::vector<int> page_index_array, std::vector<double> scale_array, std::vector<bool> perspective_array, std::vector<SUPoint3D> target_array, double reflected);


int main(int argc, const char* argv[]) {
    
    if (argc < 2){
        std::cout << "Wrong number of arguments." << std::endl;
        return -1;
    }
    
	std::string path = argv[2];
		std::string file_path = argv[2];

	size_t path_end = path.find_last_of("\\/");
    if (path_end != std::string::npos){
         file_path = path.substr(0, path_end + 1);
    }

    if (OS_WIN){
        std::string temp_file = file_path + "skalp_output.txt";
        std::freopen(temp_file.c_str(), "w", stdout);
    }

    //temp_dir, layer_names
    if (std::string(argv[1]) == "create_layer_materials"){

		std::string layer_names = base64_decode(argv[3]);
        bool result = create_layer_materials(argv[2], convert_string_array(layer_names));
        
        if (result){
            std::cout << "true";
        }else{
            std::cout << "false";
        }
    }

    if (std::string(argv[1]) == "setup_hiddenline_style"){
        setup_hiddenline_style(argv[2]);
    }

        if (std::string(argv[1]) == "modifyStyle"){
            modifyStyle(argv[2], argv[3]);
        }
    
    if (std::string(argv[1]) == "create_white_model"){
		SUMaterialRef material = SU_INVALID;
        create_white_model(argv[2], "", material);
    }
    if (std::string(argv[1]) == "color_fase"){
      
        create_white_model(argv[2], argv[3], create_color_material("Fase Color", 1.0, convert_integer(argv[4]), convert_integer(argv[5]), convert_integer(argv[6])));
    }

    //temp_dir, index_array, reversed_eye_array, reversed_target_array, transformation_array, group_id_array, up_vector_array, modelbounds
    if (std::string(argv[1]) == "setup_reversed_scene"){
        bool result = setup_reversed_scene(argv[2], argv[3], convert_integer_array(argv[4]), convert_point3D_array(argv[5]), convert_point3D_array(argv[6]), convert_transformation_array(argv[7]),
                             convert_string_array(argv[8]), convert_vector_array(argv[9]), convert_double(argv[10]));
        
        if (result){
            std::cout << "true";
        }else{
            std::cout << error_string;
        }
    }
    
    //temp_model, height, index_array, scale_array, perspective_array, target_array, rear_view)
    if (std::string(argv[1]) == "get_exploded_entities"){
        //debug_time("start get exploded entities");
        std::vector<hiddenlines> hiddenlines;
        hiddenlines = get_exploded_entities(argv[2], convert_double(argv[3]), convert_integer_array(argv[4]), convert_double_array(argv[5]), convert_boolean_array(argv[6]),
                              convert_point3D_array(argv[7]), convert_double(argv[8]));
        
        for (size_t j = 0; j < hiddenlines.size(); ++j) {
            std::cout << "*I*" + std::to_string(static_cast<long long> (hiddenlines[j].index)) << std::endl;
            std::cout << "*T*" + point_to_string(hiddenlines[j].target_point) << std::endl;
            for (size_t i = 0 ; i < hiddenlines[j].lines.size(); ++i){
                std::cout << "*L*R" + std::to_string(hiddenlines[j].lines[i].layer_index_R) + "G" + std::to_string(hiddenlines[j].lines[i].layer_index_G) + "B" + std::to_string(hiddenlines[j].lines[i].layer_index_B) + line_to_string(hiddenlines[j].lines[i]) << std::endl;
            }
            std::cout << "*E*" << std::endl;
        }
    }
 
    return(0);
}
