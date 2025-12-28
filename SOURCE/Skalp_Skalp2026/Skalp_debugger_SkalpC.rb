module Skalp
  class << self
    def skalp_requires_debug
      to_require = ["Skalp_converter.rb", "Skalp_tree.rb", "Skalp_layer.rb", "Skalp_page.rb", "Skalp_visibility.rb",
                    "Skalp_section2D.rb", "Skalp_sectionplane.rb", "Skalp_section.rb", "Skalp_model.rb", "Skalp_algorithm.rb",
                    "Skalp_control_center.rb", "Skalp_pages_undoredo.rb", "Skalp_dxf.rb", "Skalp_memory_attributes.rb", "Skalp_materials.rb", "Skalp_fog.rb",
                    "Skalp_dashed_lines.rb", "Skalp_hiddenlines.rb", "Skalp_multipolygon.rb", "Skalp_style_settings.rb",
                    "Skalp_webdialog.rb", "Skalp_section_dialog.rb", "Skalp_hatch_dialog.rb", "Skalp_tile_size.rb",
                    "Skalp_style_rules.rb", "Skalp_rendering_options.rb", "Skalp_export_import_materials.rb", "Skalp_scenes2images.rb", "Skalp_box_section.rb", "Skalp_box_section_tool.rb"]

      to_require.each do |file|
        require "Skalp_Skalp2026/#{file}"
      end
    end

    alias skalp_requires skalp_requires_debug

    def skalp_require_dialog_debug
      to_require = ["Skalp_style_settings.rb", "Skalp_webdialog.rb", "Skalp_section_dialog.rb", "Skalp_hatch_dialog.rb", "Skalp_tile_size.rb",
                    "Skalp_style_rules.rb", "Skalp_rendering_options.rb", "Skalp_export_import_materials.rb", "Skalp_scenes2images.rb"]

      to_require.each do |file|
        require "Skalp_Skalp2026/#{file}"
      end
    end

    alias skalp_require_dialog skalp_require_dialog_debug

    def skalp_require_isolate_debug
      require "Skalp_Skalp2026/Skalp_isolate"
    end

    alias skalp_require_isolate skalp_require_isolate_debug

    def skalp_require_hatch_lib_debug
      require "Skalp_Skalp2026/Skalp_hatch_lib"
    end

    alias skalp_require_hatch_lib skalp_require_hatch_lib_debug

    def skalp_require_hatchtile_debug
      require "Skalp_Skalp2026/Skalp_hatchtile"
    end

    alias skalp_require_hatchtile skalp_require_hatchtile_debug

    def skalp_require_hatch_class_debug
      require "Skalp_Skalp2026/Skalp_hatch_class"
    end

    alias skalp_require_hatch_class skalp_require_hatch_class_debug

    def skalp_require_hatchdefinition_class_debug
      require "Skalp_Skalp2026/Skalp_hatchdefinition_class"
    end

    alias skalp_require_hatchdefinition_class skalp_require_hatchdefinition_class_debug

    def skalp_require_hatchline_class_debug
      require "Skalp_Skalp2026/Skalp_hatchline_class"
    end

    alias skalp_require_hatchline_class skalp_require_hatchline_class_debug

    def skalp_require_hatchpatterns_main_debug
      require "Skalp_Skalp2026/Skalp_hatchpatterns_main"
    end

    alias skalp_require_hatchpatterns_main skalp_require_hatchpatterns_main_debug

    def skalp_require_license_debug
      require "Skalp_Skalp2026/macaddr"
      require "Skalp_Skalp2026/Skalp_license"
    end

    alias skalp_require_license skalp_require_license_debug

    def skalp_require_run_debug
      load "Skalp_Skalp2026/Skalp_start.rb"
    end

    alias skalp_require_run skalp_require_run_debug
  end
end
