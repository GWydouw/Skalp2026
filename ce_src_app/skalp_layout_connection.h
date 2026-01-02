#ifndef SKALP_LAYOUT_CONNECTION_H
#define SKALP_LAYOUT_CONNECTION_H

#include <string>
#include <vector>

bool create_layout_scrapbook(std::string source_skp_path,
                             std::string output_layout_path,
                             std::string paper_size, bool show_debug);

#endif
