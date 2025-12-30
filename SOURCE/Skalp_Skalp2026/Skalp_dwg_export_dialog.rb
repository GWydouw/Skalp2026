module Skalp
  @html_path = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/"

  attr_reader :dwg_export_dialog, :export_scenes, :where, :fileformat, :export_type, :layer_preset

  def self.dwg_export
    dxf_files_created = []
    if Cad_File_Converter.install_teigha
      Skalp.timer_started = false
      Skalp.converter_started = false
      Skalp.load_dwg_export_dialog
      if Skalp.export_scenes
        case Skalp.fileformat
        when "ac9"
          type = "DWG"
          format = "ACAD9"
        when "ac10"
          type = "DWG"
          format = "ACAD10"
        when "ac12"
          type = "DWG"
          format = "ACAD12"
        when "ac13"
          type = "DWG"
          format = "ACAD13"
        when "ac14"
          type = "DWG"
          format = "ACAD14"
        when "ac2000"
          type = "DWG"
          format = "ACAD2000"
        when "ac2004"
          type = "DWG"
          format = "ACAD2004"
        when "ac2007"
          type = "DWG"
          format = "ACAD2007"
        when "ac2010"
          type = "DWG"
          format = "ACAD2010"
        when "ac2013"
          type = "DWG"
          format = "ACAD2013"
        when "ac2018"
          type = "DWG"
          format = "ACAD2018"
        when "dxf9"
          type = "DXF"
          format = "ACAD9"
        when "dxf10"
          type = "DXF"
          format = "ACAD10"
        when "dxf12"
          type = "DXF"
          format = "ACAD12"
        when "dxf13"
          type = "DXF"
          format = "ACAD13"
        when "dxf14"
          type = "DXF"
          format = "ACAD14"
        when "dxf2000"
          type = "DXF"
          format = "ACAD2000"
        when "dxf2004"
          type = "DXF"
          format = "ACAD2004"
        when "dxf2007"
          type = "DXF"
          format = "ACAD2007"
        when "dxf2010"
          type = "DXF"
          format = "ACAD2010"
        when "dxf2013"
          type = "DXF"
          format = "ACAD2013"
        when "dxf2018"
          type = "DXF"
          format = "ACAD2018"
        else
        end

        Cad_File_Converter.output_version = format
        Cad_File_Converter.output_file_type = type

        if Skalp.where == "path"
          filename = if format == "DXF"
                       File.basename(Skalp.active_model.skpModel.path.gsub(".skp", ".dxf"))
                     else
                       File.basename(Skalp.active_model.skpModel.path.gsub(".skp", ".dwg"))
                     end

          directory = Skalp.active_model.skpModel.path.gsub(File.basename(Skalp.active_model.skpModel.path), "")
          path = UI.savepanel("Export dwg/dxf to...", directory, filename)

          filename = File.basename(path, File.extname(path))
          filename = Skalp.remove_scene_name(filename)
          Cad_File_Converter.output_path = File.dirname(path)
        else
          filename = File.basename(Skalp.active_model.skpModel.path, ".*")
          Cad_File_Converter.output_path = File.dirname(Skalp.active_model.skpModel.path)
        end

        Cad_File_Converter.input_path = Skalp.dialog.dxf_path = Skalp.create_temp_dir
        FileUtils.rm_f(Dir.glob("#{Skalp.dialog.dxf_path}*.dxf"))

        if Skalp.active_model && Skalp.active_model.skpModel.path != ""
          # Adaptive weighting for DWG Export
          w_sections = Skalp.get_avg_timing("dwg_export_sections", 1.0)
          w_forward = Skalp.get_avg_timing("dwg_export_forward", 1.0)
          w_rear = Skalp.get_avg_timing("dwg_export_rear", 5.0)
          w_cad = Skalp.get_avg_timing("dwg_export_cad", 10.0)

          scenes_to_export = Skalp.export_type == "Scenes" ? export_scene_list : [Skalp.active_model.skpModel.pages.selected_page || Skalp.active_model.skpModel]
          total_weight = (scenes_to_export.size * (w_sections + w_forward + w_rear)) + w_cad

          progress = Skalp::ProgressDialog.new(Skalp.translate("DWG/DXF Export"), total_weight)
          progress.show
          Skalp.progress_dialog = progress

          if OS == :WINDOWS
            if Skalp.export_type == "Active View"
              progress.offset = 0
              progress.phase(Skalp.translate("Updating section"))
              Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating section')}"
              t_start_sections = Time.now
              if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
                Skalp.active_model.active_sectionplane.calculate_section
              end
              Skalp.record_timing("dwg_export_sections", Time.now - t_start_sections)

              progress.offset = w_sections
              progress.phase(Skalp.translate("Updating forward view"))
              Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating forward view')}"
              t_start_forward = Time.now
              Skalp.active_model.hiddenlines.update_forward_lines
              Skalp.record_timing("dwg_export_forward", Time.now - t_start_forward)

              progress.phase(Skalp.translate("Updating rear view"))
              Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating rear view')}"
              t_start_rear = Time.now
              if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
                Skalp.active_model.hiddenlines.update_rear_lines(:active, false, w_rear)
              end
              Skalp.record_timing("dwg_export_rear", Time.now - t_start_rear)

              progress.offset = w_sections + w_forward + w_rear
              progress.phase(Skalp.translate("Exporting files"))
              Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Exporting files')}"
              Skalp.active_model.export_dxf_pages(filename, Skalp.layer_preset)
              Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Finished!')}"
            elsif Skalp.export_type == "Scenes"
              if Skalp.active_model.skpModel.pages.count > 0 && Skalp.export_scenes
                progress.offset = 0
                progress.phase(Skalp.translate("Updating sections"))
                Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating sections')}"
                t_start_sections = Time.now
                Skalp.active_model.update_selected_pages_dxf do |scene_idx, scene_name|
                  # Use scene_idx * w_sections for correct weighting
                  progress.update((scene_idx - 1) * w_sections, Skalp.translate("Updating section"), scene_name)
                end
                Skalp.record_timing("dwg_export_sections",
                                    (Time.now - t_start_sections) / [scenes_to_export.size, 1].max)
                Skalp.active_model.manage_scenes

                progress.offset = scenes_to_export.size * w_sections
                progress.phase(Skalp.translate("Updating forward view"))
                Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating forward view')}"
                t_start_forward = Time.now
                Skalp.active_model.hiddenlines.update_forward_lines(:selected)
                Skalp.record_timing("dwg_export_forward", (Time.now - t_start_forward) / [scenes_to_export.size, 1].max)

                progress.offset = scenes_to_export.size * (w_sections + w_forward)
                progress.phase(Skalp.translate("Updating rear view"))
                Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating rear view')}"
                t_start_rear = Time.now
                Skalp.active_model.hiddenlines.update_rear_lines(:selected, false, w_rear)
                Skalp.record_timing("dwg_export_rear", (Time.now - t_start_rear) / [scenes_to_export.size, 1].max)

                progress.offset = scenes_to_export.size * (w_sections + w_forward + w_rear)
                progress.phase(Skalp.translate("Exporting files"))
                Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Exporting files')}"
                Skalp.active_model.export_selected_pages_dxf(filename, Skalp.layer_preset)
                Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Finished!')}"
              end
            end
            Skalp.active_model.active_section && Skalp.dialog.style_settings(@skpModel)[:rearview_status] && Skalp.active_model.active_section.place_rear_view_lines_in_model
          else
            # Mac branch with timers
            UI.start_timer(0.01, false) do
              if Skalp.export_type == "Active View"
                progress.offset = 0
                progress.phase(Skalp.translate("Updating section"))
                progress.update(0.1, Skalp.translate("Updating section"), "")
                Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating section')}"
                t_start_sections = Time.now
                if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
                  Skalp.active_model.active_sectionplane.calculate_section
                end
                Skalp.record_timing("dwg_export_sections", Time.now - t_start_sections)

                UI.start_timer(0.01, false) do
                  progress.offset = w_sections
                  progress.phase(Skalp.translate("Updating forward view"))
                  progress.update(0.1, Skalp.translate("Updating forward view"), "")
                  Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating forward view')}"
                  t_start_forward = Time.now
                  Skalp.active_model.hiddenlines.update_forward_lines
                  Skalp.record_timing("dwg_export_forward", Time.now - t_start_forward)

                  UI.start_timer(0.01, false) do
                    progress.phase(Skalp.translate("Updating rear view"))
                    Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating rear view')}"
                    t_start_rear = Time.now
                    if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
                      Skalp.active_model.hiddenlines.update_rear_lines(:active, false, w_rear)
                    end
                    Skalp.record_timing("dwg_export_rear", Time.now - t_start_rear)

                    UI.start_timer(0.01, false) do
                      progress.offset = w_sections + w_forward + w_rear
                      progress.phase(Skalp.translate("Exporting files"))
                      progress.update(0.1, Skalp.translate("Exporting files"), "")
                      Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Exporting files')}"
                      Skalp.active_model.export_dxf_pages(filename, Skalp.layer_preset)
                    end
                  end
                end
              elsif Skalp.export_type == "Scenes"
                if Skalp.active_model.skpModel.pages.count > 0 && Skalp.export_scenes
                  progress.offset = 0
                  progress.phase(Skalp.translate("Updating sections"))
                  Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating sections')}"
                  t_start_sections = Time.now

                  scene_idx = 0
                  process_scenes_block = lambda do
                    if scene_idx < scenes_to_export.size
                      skpPage = scenes_to_export[scene_idx]
                      if Skalp.active_model.get_memory_attribute(skpPage, "Skalp", "ID")
                        progress.update(scene_idx * w_sections, Skalp.translate("Updating section"), skpPage.name)
                        sectionplane_id = Skalp.active_model.get_memory_attribute(skpPage, "Skalp", "sectionplaneID")
                        sp = Skalp.active_model.sectionplane_by_id(sectionplane_id)
                        sp.calculate_section(false, skpPage) if sp
                      end
                      scene_idx += 1
                      UI.start_timer(0.01, false) { process_scenes_block.call }
                    else
                      # Done with Phase 1
                      Skalp.record_timing("dwg_export_sections",
                                          (Time.now - t_start_sections) / [scenes_to_export.size, 1].max)
                      Skalp.active_model.manage_scenes

                      # Phase 2: Forward View
                      UI.start_timer(0.01, false) do
                        progress.offset = scenes_to_export.size * w_sections
                        progress.phase(Skalp.translate("Updating forward view"))
                        Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating forward view')}"
                        t_start_forward = Time.now
                        Skalp.active_model.hiddenlines.update_forward_lines(:selected)
                        Skalp.record_timing("dwg_export_forward",
                                            (Time.now - t_start_forward) / [scenes_to_export.size, 1].max)

                        # Phase 3: Rear View
                        UI.start_timer(0.01, false) do
                          progress.offset = scenes_to_export.size * (w_sections + w_forward)
                          progress.phase(Skalp.translate("Updating rear view"))
                          Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Updating rear view')}"
                          t_start_rear = Time.now
                          Skalp.active_model.hiddenlines.update_rear_lines(:selected, false, w_rear)
                          Skalp.record_timing("dwg_export_rear",
                                              (Time.now - t_start_rear) / [scenes_to_export.size, 1].max)

                          # Phase 4: Exporting
                          UI.start_timer(0.01, false) do
                            progress.offset = scenes_to_export.size * (w_sections + w_forward + w_rear)
                            progress.phase(Skalp.translate("Exporting files"))
                            Sketchup.set_status_text "#{Skalp.translate('Skalp:')} #{Skalp.translate('Exporting files')}"
                            Skalp.active_model.export_selected_pages_dxf(filename, Skalp.layer_preset)
                          end
                        end
                      end
                    end
                  end
                  process_scenes_block.call
                end
              end

              UI.start_timer(0.01, false) do
                Skalp.active_model.active_section && Skalp.dialog.style_settings(@skpModel)[:rearview_status] && Skalp.active_model.active_section.place_rear_view_lines_in_model
              end
            end
          end

          # Final conversion step
          UI.start_timer(0.01, false) do
            unless Skalp.converter_started
              Skalp.converter_started = true
              progress.offset = total_weight - w_cad
              progress.phase(Skalp.translate("Converting to DWG/DXF..."))
              t_start_cad = Time.now
              progress.update(0.1, Skalp.translate("Converting to DWG/DXF..."), "")
              Cad_File_Converter.convert
              Skalp.record_timing("dwg_export_cad", Time.now - t_start_cad)
            end
            progress.close
            Skalp.progress_dialog = nil
            Skalp.exportDWGbutton_off
          end
        else
          UI.messagebox(Skalp.translate("Your model must be saved before you can export your Skalp section to dwg/dxf."))
          Skalp.exportDWGbutton_off
        end
      end
    else
      UI.messagebox("DXF/DWG file converter isn't installed! You need to be online to install the DXF/DWG converter")
    end
  end

  def self.load_dwg_export_dialog
    if OS == :WINDOWS
      hdpi_scale = UI.scale_factor.to_i
      min_w = 351
      min_h = 442
    else
      hdpi_scale = 1
      min_w = 336
      min_h = 418
    end

    @dwg_export_dialog = UI::HtmlDialog.new(
      {
        dialog_title: "DWG/DXF Export",
        preferences_key: "Skalp.plugin",
        scrollable: false,
        resizable: true,
        width: 384 * hdpi_scale,
        height: 500 * hdpi_scale,
        left: 100 * hdpi_scale,
        top: 100 * hdpi_scale,
        min_width: min_w * hdpi_scale,
        min_height: min_h * hdpi_scale,
        max_width: 1000 * hdpi_scale,
        max_height: 1000 * hdpi_scale,
        style: UI::HtmlDialog::STYLE_DIALOG
      }
    )

    @dwg_export_dialog.set_file(@html_path + "dwg_export_dialog.html")

    @dwg_export_dialog.add_action_callback("change_section_layer") do |action_context, params|
      @section_layer = params
      @dwg_export_dialog.execute_script("set_value('fill_layer', '#{@section_layer}')")
      @dwg_export_dialog.execute_script("set_value('hatch_layer', '#{@section_layer}')")
      disable_suffixes
    end

    @dwg_export_dialog.add_action_callback("change_section_suffix") do |action_context, params|
      @section_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('section_suffix', '#{@section_suffix}')")
    end

    @dwg_export_dialog.add_action_callback("change_hath_suffix") do |action_context, params|
      @hatch_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('hatch_suffix', '#{@hatch_suffix}')")
    end

    @dwg_export_dialog.add_action_callback("change_fill_suffix") do |action_context, params|
      @fill_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('fill_suffix', '#{@fill_suffix}')")
    end

    @dwg_export_dialog.add_action_callback("change_forward_layer") do |action_context, params|
      @forward_layer = params
      disable_suffixes
    end

    @dwg_export_dialog.add_action_callback("change_forward_suffix") do |action_context, params|
      @forward_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('forward_suffix', '#{@forward_suffix}')")
    end

    @dwg_export_dialog.add_action_callback("change_forward_color") do |action_context, params|
      @forward_color = params
    end

    @dwg_export_dialog.add_action_callback("change_rear_layer") do |action_context, params|
      @rear_layer = params
      disable_suffixes
    end

    @dwg_export_dialog.add_action_callback("change_rear_suffix") do |action_context, params|
      @rear_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('rear_suffix', '#{@rear_suffix}')")
    end

    @dwg_export_dialog.add_action_callback("change_rear_color") do |action_context, params|
      @rear_color = params
    end

    @dwg_export_dialog.add_action_callback("change_where") do |action_context, params|
      @where = params
    end

    @dwg_export_dialog.add_action_callback("change_fileformat") do |action_context, params|
      @fileformat = params
    end

    @dwg_export_dialog.add_action_callback("dialog_ready") do |action_context, params|
      load_scenes
      set_selects
      disable_suffixes
      @export = false

      @dwg_export_dialog.execute_script("resize_dialog()")
    end

    @dwg_export_dialog.add_action_callback("resize_dialog") do |action_context, params|
      params = params.split(";")
      w = params[0].to_i
      h = params[1].to_i
    end

    @dwg_export_dialog.add_action_callback("cancel") do |action_context, params|
      @export = true
      @export_scenes = false
      @dwg_export_dialog.close
    end

    @dwg_export_dialog.add_action_callback("export") do |action_context, params|
      @dwg_export_dialog.close
      write_export_scene_list
      save_selects

      if export_scene_list.size == 0 && @export_type == "Scenes"
        UI.messagebox("No scenes selected to export.")
        @export_scenes = false
      else
        @export_scenes = true
      end
      @export = true
    end

    @dwg_export_dialog.set_on_closed do
      unless @export
        @export_scenes = false
        Skalp.exportDWGbutton_off
      end
    end

    @dwg_export_dialog.add_action_callback("scene_selected") do |action_context, params|
      vars = params.split(";")
      name = vars[0]
      status = vars[1]

      status = if status.to_s == "true"
                 "true"
               else
                 "false"
               end

      @scene_status[name] = status
    end

    @dwg_export_dialog.show_modal
  end

  def self.disable_suffixes
    if @section_layer == "fixed"
      @dwg_export_dialog.execute_script("disable_input('section_suffix', true)")
      @dwg_export_dialog.execute_script("disable_input('label_section_suffix', true)")
    else
      @dwg_export_dialog.execute_script("disable_input('section_suffix', false)")
      @dwg_export_dialog.execute_script("disable_input('label_section_suffix', false)")
    end

    if @forward_layer == "fixed"
      @dwg_export_dialog.execute_script("disable_input('forward_suffix', true)")
      @dwg_export_dialog.execute_script("disable_input('label_forward_suffix', true)")
    else
      @dwg_export_dialog.execute_script("disable_input('forward_suffix', false)")
      @dwg_export_dialog.execute_script("disable_input('label_forward_suffix', false)")
    end

    if @rear_layer == "fixed"
      @dwg_export_dialog.execute_script("disable_input('rear_suffix', true)")
      @dwg_export_dialog.execute_script("disable_input('label_rear_suffix', true)")
    else
      @dwg_export_dialog.execute_script("disable_input('rear_suffix', false)")
      @dwg_export_dialog.execute_script("disable_input('label_rear_suffix', false)")
    end
  end

  def self.set_selects
    @section_layer = Sketchup.read_default("Skalp_export", "section_layer") || "object"
    @section_suffix = Sketchup.read_default("Skalp_export", "section_suffix") || "-S"
    @hatch_suffix = Sketchup.read_default("Skalp_export", "hatch_suffix") || "-SH"
    @fill_suffix = Sketchup.read_default("Skalp_export", "fill_suffix") || "-SF"
    @forward_layer = Sketchup.read_default("Skalp_export", "forward_layer") || "layers"
    @forward_suffix = Sketchup.read_default("Skalp_export", "forward_suffix") || "-F"
    @forward_color = Sketchup.read_default("Skalp_export", "forward_color") || "black"
    @rear_layer = Sketchup.read_default("Skalp_export", "rear_layer") || "layers"
    @rear_suffix = Sketchup.read_default("Skalp_export", "rear_suffix") || "-R"
    @rear_color = Sketchup.read_default("Skalp_export", "rear_color") || "black"

    @fileformat = Sketchup.read_default("Skalp_export", "fileformat") || "ac2018"
    @where = Sketchup.read_default("Skalp_export", "where") || "model"

    @dwg_export_dialog.execute_script("set_value('section_layer', '#{@section_layer}')")
    @dwg_export_dialog.execute_script("set_value('fill_layer', '#{@section_layer}')")
    @dwg_export_dialog.execute_script("set_value('hatch_layer', '#{@section_layer}')")
    @dwg_export_dialog.execute_script("set_value('section_suffix', '#{@section_suffix}')")
    @dwg_export_dialog.execute_script("set_value('hatch_suffix', '#{@hatch_suffix}')")
    @dwg_export_dialog.execute_script("set_value('fill_suffix', '#{@fill_suffix}')")
    @dwg_export_dialog.execute_script("set_value('forward_layer', '#{@forward_layer}')")
    @dwg_export_dialog.execute_script("set_value('forward_suffix', '#{@forward_suffix}')")
    @dwg_export_dialog.execute_script("set_value('forward_color', '#{@forward_color}')")
    @dwg_export_dialog.execute_script("set_value('rear_layer', '#{@rear_layer}')")
    @dwg_export_dialog.execute_script("set_value('rear_suffix', '#{@rear_suffix}')")
    @dwg_export_dialog.execute_script("set_value('rear_color', '#{@rear_color}')")
    @dwg_export_dialog.execute_script("set_value('fileformat_select', '#{@fileformat}')")
    @dwg_export_dialog.execute_script("set_value('where_select', '#{@where}')")
  end

  def self.save_selects
    Sketchup.write_default("Skalp_export", "section_layer", @section_layer)
    Sketchup.write_default("Skalp_export", "section_suffix", @section_suffix)
    Sketchup.write_default("Skalp_export", "fill_suffix", @fill_suffix)
    Sketchup.write_default("Skalp_export", "hatch_suffix", @hatch_suffix)
    Sketchup.write_default("Skalp_export", "forward_layer", @forward_layer)
    Sketchup.write_default("Skalp_export", "forward_suffix", @forward_suffix)
    Sketchup.write_default("Skalp_export", "forward_color", @forward_color)
    Sketchup.write_default("Skalp_export", "rear_layer", @rear_layer)
    Sketchup.write_default("Skalp_export", "rear_suffix", @rear_suffix)
    Sketchup.write_default("Skalp_export", "rear_color", @rear_color)

    Sketchup.write_default("Skalp_export", "fileformat", @fileformat)
    Sketchup.write_default("Skalp_export", "where", @where)

    @layer_preset = {}
    @layer_preset[:section_layer] = @section_layer
    @layer_preset[:section_suffix] = @section_suffix
    @layer_preset[:hatch_suffix] = @hatch_suffix
    @layer_preset[:fill_suffix] = @fill_suffix
    @layer_preset[:forward_layer] = @forward_layer
    @layer_preset[:forward_suffix] = @forward_suffix
    @layer_preset[:forward_color] = @forward_color
    @layer_preset[:rear_layer] = @rear_layer
    @layer_preset[:rear_suffix] = @rear_suffix
    @layer_preset[:rear_color] = @rear_color
    @layer_preset[:fileformat] = @fileformat
    @layer_preset[:where] = @where
  end

  def self.load_scenes
    read_export_scene_list
    Skalp.active_model.skpModel.pages.each do |page|
      @export_type = "Scenes"
      selected = @scene_status[page.name]
      unless selected
        selected = "false"
        @scene_status[page.name] = selected
      end
      add_scene_to_dialog(page.name, selected)
    end

    return unless Skalp.active_model.skpModel.pages.count == 0

    @export_type = "Active View"
    add_scene_to_dialog("Active View", "true")

    # @dwg_export_dialog.execute_script("reset_table_size()")
  end

  def self.add_scene_to_dialog(scenename, selected)
    checked = selected == "true" ? "checked" : ""

    script = <<~SCRIPT
      $("#scenes").append('<tr> <td class="check export"><input type="checkbox" name="#{scenename}" value="#{scenename}"  onchange="toggleCheckbox(this)" #{checked}></td><td class="scene"> #{scenename} </td></tr>');
    SCRIPT

    @dwg_export_dialog.execute_script(script)
  end

  private

  def self.export_scene_list
    read_export_scene_list

    pages = Skalp.active_model.skpModel.pages
    pages_list = []

    @scene_status.each do |pagename, status|
      page = pages[pagename]
      pages_list << page if page && status == "true"
    end

    pages_list
  end

  def self.read_export_scene_list
    attrib = Skalp.active_model.skpModel.get_attribute("Skalp_4", "export_scenes")
    @scene_status = {}
    if attrib.class == String && eval(attrib).class == Hash
      @scene_status = eval(attrib)
    else
      Skalp.active_model.skpModel.pages.each do |page|
        @scene_status[page.name] = "false"
      end
    end
  end

  def self.write_export_scene_list
    Skalp.active_model.start("Skalp - save export scenes list")
    Skalp.active_model.skpModel.set_attribute("Skalp_4", "export_scenes", @scene_status.to_s)
    Skalp.active_model.commit
  end
end
