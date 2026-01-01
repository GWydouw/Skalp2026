#include <cstdio>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// Internal project headers
#include "base64/base64.h"
#include "skalp_convert.h"
#include "sketchup.h"

// Define platform-specific flags
#ifdef _WIN32
const bool OS_WIN = true;
#else
const bool OS_WIN = false;
#endif

// Global error string for reporting failures
std::string error_string;

/**
 * debug_info
 * Prints debug information to stdout with a prefix *D*.
 * This allows the calling Ruby application to filter debug messages.
 *
 * @param debug_text: The string to print.
 */
void debug_info(std::string debug_text) {
  std::cout << "*D*" << debug_text << std::endl;
};

// Forward declarations of command functions
SUEntitiesRef get_sectiongroups(SUEntitiesRef entities);
bool remove_materials(SUModelRef model);
bool create_layer_materials(std::string path,
                            std::vector<std::string> layer_names);
bool setup_hiddenline_style(std::string path);
bool modifyStyle(std::string path, std::string new_path);
bool create_white_model(std::string path, std::string fase,
                        SUMaterialRef color_material);
bool setup_reversed_scene(std::string path, std::string new_path,
                          std::vector<int> page_index_array,
                          std::vector<SUPoint3D> eye_array,
                          std::vector<SUPoint3D> target_array,
                          std::vector<SUTransformation> transformation_array,
                          std::vector<std::string> id_array,
                          std::vector<SUVector3D> up_vector_array,
                          std::vector<std::string> sectionplane_id_array,
                          double bounds, std::string style_path);
std::vector<hiddenlines> get_exploded_entities(
    std::string path, double height, std::vector<int> page_index_array,
    std::vector<double> scale_array, std::vector<bool> perspective_array,
    std::vector<SUPoint3D> target_array, double reflected);

/**
 * Main Application Entry Point
 *
 * Defines a CLI interface for Skalp's external processing tasks.
 * The application expects the first argument to be the command name,
 * followed by command-specific arguments.
 *
 * Usage: Skalp <command> <path> [extra_args...]
 */
int main(int argc, const char *argv[]) {

  // 1. Basic Argument Validation
  if (argc < 3) {
    std::cout << "Skalp External Application" << std::endl;
    std::cout << "Usage: Skalp <command> <path> [extra_args]" << std::endl;
    return -1;
  }

  // 2. Parse common arguments
  std::string command = argv[1];
  std::string path = argv[2];
  std::string file_dir = argv[2];

  // Determine directory from path (handling both separators)
  size_t path_end = path.find_last_of("\\/");
  if (path_end != std::string::npos) {
    file_dir = path.substr(0, path_end + 1);
  }

  // 3. Windows-specific Output Redirection
  // On Windows, redirect stdout to a file to avoid console window issues or
  // buffer limits? Or perhaps to capture output persistently.
  if (OS_WIN) {
    std::string temp_file = file_dir + "skalp_output.txt";
    std::freopen(temp_file.c_str(), "w", stdout);
  }

  // 4. Command Dispatching

  // --- Command: create_layer_materials ---
  // Decodes base64 encoded layer names and creates corresponding materials.
  // expected args: command, path, encoded_layer_names
  if (command == "create_layer_materials") {
    if (argc > 3) {
      std::string layer_names_encoded = argv[3];
      std::string layer_names_decoded = base64_decode(layer_names_encoded);

      bool result = create_layer_materials(
          path, convert_string_array(layer_names_decoded));

      if (result) {
        std::cout << "true";
      } else {
        std::cout << "false";
      }
    }
  }

  // --- Command: setup_hiddenline_style ---
  // Sets up specific style settings for hidden line rendering.
  if (command == "setup_hiddenline_style") {
    setup_hiddenline_style(path);
  }

  // --- Command: modifyStyle ---
  // Modifies an existing style file.
  if (command == "modifyStyle") {
    if (argc > 3) {
      modifyStyle(path, argv[3]);
    }
  }

  // --- Command: create_white_model ---
  // Creates a "white model" version (all materials removed/whitened).
  if (command == "create_white_model") {
    SUMaterialRef material =
        SU_INVALID; // Default invalid material implies default/white
    create_white_model(path, "", material);
  }

  // --- Command: color_fase ---
  // Creates a white model but with a specific color override for a "phase"
  // (fase). args: cmd, path, fase_name, r, g, b
  if (command == "color_fase") {
    if (argc > 6) {
      double alpha = 1.0;
      int r = convert_integer(argv[4]);
      int g = convert_integer(argv[5]);
      int b = convert_integer(argv[6]);

      create_white_model(path, argv[3],
                         create_color_material("Fase Color", alpha, r, g, b));
    }
  }

  // --- Command: setup_reversed_scene ---
  // Sets up a "Reversed Scene" (Rear View mechanism).
  // args: cmd, temp_dir, index_array, reversed_eye_array,
  // reversed_target_array, transformation_array, group_id_array,
  // up_vector_array, modelbounds
  if (command == "setup_reversed_scene") {
    if (argc > 12) {
      bool result = setup_reversed_scene(
          path,
          argv[3], // output path?
          convert_integer_array(argv[4]), convert_point3D_array(argv[5]),
          convert_point3D_array(argv[6]), convert_transformation_array(argv[7]),
          convert_string_array(argv[8]), convert_vector_array(argv[9]),
          convert_string_array(argv[10]), // sectionplane_id_array
          convert_double(argv[11]),       // bounds
          argv[12]);                      // style_path

      if (result) {
        std::cout << "true";
      } else {
        std::cout << error_string;
      }
    }
  }

  // --- Command: get_exploded_entities ---
  // Core Hidden Line calculation. Explodes entities and calculates hidden
  // lines. args: cmd, temp_model, height, index_array, scale_array,
  // perspective_array, target_array, rear_view_flag
  if (command == "get_exploded_entities") {
    if (argc > 8) {
      std::vector<hiddenlines> results;
      results = get_exploded_entities(
          path, convert_double(argv[3]), convert_integer_array(argv[4]),
          convert_double_array(argv[5]), convert_boolean_array(argv[6]),
          convert_point3D_array(argv[7]), convert_double(argv[8]));

      // Output results in a structured text format for Ruby to parse
      // Format:
      // *I*<index>
      // *T*<target_point>
      // *L*R<r>G<g>B<b><line_coords>
      // *E* (End of entry)
      for (size_t j = 0; j < results.size(); ++j) {
        std::cout << "*I*" + std::to_string(
                                 static_cast<long long>(results[j].index))
                  << std::endl;
        std::cout << "*T*" + point_to_string(results[j].target_point)
                  << std::endl;
        for (size_t i = 0; i < results[j].lines.size(); ++i) {
          std::cout << "*L*R"
                    << std::to_string(results[j].lines[i].layer_index_R) << "G"
                    << std::to_string(results[j].lines[i].layer_index_G) << "B"
                    << std::to_string(results[j].lines[i].layer_index_B)
                    << line_to_string(results[j].lines[i]) << std::endl;
        }
        std::cout << "*E*" << std::endl;
      }
    }
  }

  return 0;
}
