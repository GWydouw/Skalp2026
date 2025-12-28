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
        when 'ac9'
          type = "DWG"
          format = "ACAD9"
        when 'ac10'
          type = "DWG"
          format = "ACAD10"
        when 'ac12'
          type = "DWG"
          format = "ACAD12"
        when 'ac13'
          type = "DWG"
          format = "ACAD13"
        when 'ac14'
          type = "DWG"
          format = "ACAD14"
        when 'ac2000'
          type = "DWG"
          format = "ACAD2000"
        when 'ac2004'
          type = "DWG"
          format = "ACAD2004"
        when 'ac2007'
          type = "DWG"
          format = "ACAD2007"
        when 'ac2010'
          type = "DWG"
          format = "ACAD2010"
        when 'ac2013'
          type = "DWG"
          format = "ACAD2013"
        when 'ac2018'
          type = "DWG"
          format = "ACAD2018"
        when 'dxf9'
          type = "DXF"
          format = "ACAD9"
        when 'dxf10'
          type = "DXF"
          format = "ACAD10"
        when 'dxf12'
          type = "DXF"
          format = "ACAD12"
        when 'dxf13'
          type = "DXF"
          format = "ACAD13"
        when 'dxf14'
          type = "DXF"
          format = "ACAD14"
        when 'dxf2000'
          type = "DXF"
          format = "ACAD2000"
        when 'dxf2004'
          type = "DXF"
          format = "ACAD2004"
        when 'dxf2007'
          type = "DXF"
          format = "ACAD2007"
        when 'dxf2010'
          type = "DXF"
          format = "ACAD2010"
        when 'dxf2013'
          type = "DXF"
          format = "ACAD2013"
        when 'dxf2018'
          type = "DXF"
          format = "ACAD2018"
        else
        end

        Cad_File_Converter.output_version = format
        Cad_File_Converter.output_file_type = type

        if Skalp.where == 'path'
          if format == 'DXF'
            filename = File.basename(Skalp.active_model.skpModel.path.gsub(".skp", ".dxf"))
          else
            filename = File.basename(Skalp.active_model.skpModel.path.gsub(".skp", ".dwg"))
          end

          directory = Skalp.active_model.skpModel.path.gsub(File.basename(Skalp.active_model.skpModel.path), '')
          path = UI.savepanel("Export dwg/dxf to...", directory, filename)

          filename = File.basename(path, File.extname(path))
          filename = Skalp::remove_scene_name(filename)
          Cad_File_Converter.output_path = File.dirname(path)
        else
          filename = File.basename(Skalp.active_model.skpModel.path).gsub('.skp', '')
          Cad_File_Converter.output_path =  File.dirname(Skalp.active_model.skpModel.path) #Skalp.active_model.skpModel.path.gsub(File.basename(Skalp.active_model.skpModel.path), '')
        end

        Cad_File_Converter.input_path = Skalp.dialog.dxf_path = Skalp::create_temp_dir
        FileUtils.rm_f(Dir.glob("#{Skalp.dialog.dxf_path}*.dxf"))

        if Skalp.active_model && Skalp.active_model.skpModel.path != ''

          if OS == :WINDOWS
            if Skalp.export_type == 'Active View'
              Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing sections')} (#{Skalp.translate('step')} 1/4). #{Skalp.translate('Please wait...')}"
              Skalp.active_model.active_sectionplane.calculate_section if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
              Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing forward view')} (#{Skalp.translate('step')} 2/4). #{Skalp.translate('Please wait...')}"
              Skalp.active_model.hiddenlines.update_forward_lines
              Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing rear view')} (#{Skalp.translate('step')} 3/4). #{Skalp.translate('Please wait...')}"
              Skalp.active_model.hiddenlines.update_rear_lines(:active, false) if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
              Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Export scenes to dwg/dxf files')} (#{Skalp.translate('step')} 4/4). #{Skalp.translate('Please wait...')}"
              Skalp.active_model.export_dxf_pages(filename, Skalp.layer_preset)
              Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Finished!')}"
            elsif Skalp.export_type == 'Scenes'
              if Skalp.active_model.skpModel.pages.count > 0 && Skalp.export_scenes
                Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing sections')} (#{Skalp.translate('step')} 1/4). #{Skalp.translate('Please wait...')}"
                Skalp.active_model.update_selected_pages_dxf
                Skalp.active_model.manage_scenes
                Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing forward view')} (#{Skalp.translate('step')} 2/4). #{Skalp.translate('Please wait...')}"
                Skalp.active_model.hiddenlines.update_forward_lines(:selected)
                Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing rear view')} (#{Skalp.translate('step')} 3/4). #{Skalp.translate('Please wait...')}"
                Skalp.active_model.hiddenlines.update_rear_lines(:selected, false)
                Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Export scenes to dwg/dxf files')} (#{Skalp.translate('step')} 4/4). #{Skalp.translate('Please wait...')}"
                Skalp.active_model.export_selected_pages_dxf(filename, Skalp.layer_preset)
                Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Finished!')}"
              end
            end
            Skalp.active_model.active_section && Skalp.dialog.style_settings(@skpModel)[:rearview_status] && Skalp.active_model.active_section.place_rear_view_lines_in_model
          else
            if Skalp.export_type == 'Active View'
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing sections')} (#{Skalp.translate('step')} 1/4). #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { Skalp.active_model.active_sectionplane.calculate_section } if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing forward view')} (#{Skalp.translate('step')} 2/4). #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.update_forward_lines }
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing rear view')} (#{Skalp.translate('step')} 3/4). #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.update_rear_lines(:active, false) } if Skalp.active_model.skpModel == @active_skpModel && Skalp.active_model.active_sectionplane
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Export scenes to dwg/dxf files')} (#{Skalp.translate('step')} 4/4). #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { Skalp.active_model.export_dxf_pages(filename, Skalp.layer_preset) }
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Finished!')}" }

            elsif Skalp.export_type == 'Scenes'
              if Skalp.active_model.skpModel.pages.count > 0 && Skalp.export_scenes
                UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing sections')} (#{Skalp.translate('step')} 1/4). #{Skalp.translate('Please wait...')}" }
                UI.start_timer(0.01, false) do
                  Skalp.active_model.update_selected_pages_dxf
                  Skalp.active_model.manage_scenes
                end
                UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing forward view')} (#{Skalp.translate('step')} 2/4). #{Skalp.translate('Please wait...')}" }
                UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.update_forward_lines(:selected) }
                UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Processing rear view')} (#{Skalp.translate('step')} 3/4). #{Skalp.translate('Please wait...')}" }
                UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.update_rear_lines(:selected, false) }
                UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Export scenes to dxf files')} (#{Skalp.translate('step')} 4/4). #{Skalp.translate('Please wait...')}" }
                UI.start_timer(0.01, false) { Skalp.active_model.export_selected_pages_dxf(filename, Skalp.layer_preset) }
                UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('DWG/DXF export:')} #{Skalp.translate('Finished!')}" }
              end
            end

            UI.start_timer(0.01, false) {
              Skalp.active_model.active_section && Skalp.dialog.style_settings(@skpModel)[:rearview_status] && Skalp.active_model.active_section.place_rear_view_lines_in_model
            }

          end
          UI.start_timer(0.01, false) {
            unless Skalp.converter_started
              Skalp.converter_started = true
              Cad_File_Converter.convert
            end
            Skalp.exportDWGbutton_off
          }
        else
          UI.messagebox(Skalp.translate('Your model must be saved before you can export your Skalp section to dwg/dxf.'))
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
        :dialog_title => "DWG/DXF Export",
        :preferences_key => "Skalp.plugin",
        :scrollable => false,
        :resizable => true,
        :width => 384 * hdpi_scale,
        :height => 500 * hdpi_scale,
        :left => 100 * hdpi_scale,
        :top => 100 * hdpi_scale,
        :min_width => min_w * hdpi_scale,
        :min_height => min_h * hdpi_scale,
        :max_width => 1000 * hdpi_scale,
        :max_height => 1000 * hdpi_scale,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

    @dwg_export_dialog.set_file(@html_path + "dwg_export_dialog.html")

    @dwg_export_dialog.add_action_callback("change_section_layer") {|action_context, params|
      @section_layer = params
      @dwg_export_dialog.execute_script("set_value('fill_layer', '#{@section_layer}')")
      @dwg_export_dialog.execute_script("set_value('hatch_layer', '#{@section_layer}')")
      disable_suffixes
    }

    @dwg_export_dialog.add_action_callback("change_section_suffix") {|action_context, params|
      @section_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('section_suffix', '#{@section_suffix}')")
    }

    @dwg_export_dialog.add_action_callback("change_hath_suffix") {|action_context, params|
      @hatch_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('hatch_suffix', '#{@hatch_suffix}')")
    }

    @dwg_export_dialog.add_action_callback("change_fill_suffix") {|action_context, params|
      @fill_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('fill_suffix', '#{@fill_suffix}')")
    }

    @dwg_export_dialog.add_action_callback("change_forward_layer") {|action_context, params|
      @forward_layer = params
      disable_suffixes
    }

    @dwg_export_dialog.add_action_callback("change_forward_suffix") {|action_context, params|
      @forward_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('forward_suffix', '#{@forward_suffix}')")
    }

    @dwg_export_dialog.add_action_callback("change_forward_color") {|action_context, params|
      @forward_color = params
    }

    @dwg_export_dialog.add_action_callback("change_rear_layer") {|action_context, params|
      @rear_layer = params
      disable_suffixes
    }

    @dwg_export_dialog.add_action_callback("change_rear_suffix") {|action_context, params|
      @rear_suffix = Skalp.layer_check(params[0..5])
      @dwg_export_dialog.execute_script("set_value('rear_suffix', '#{@rear_suffix}')")
    }

    @dwg_export_dialog.add_action_callback("change_rear_color") {|action_context, params|
      @rear_color = params
    }

    @dwg_export_dialog.add_action_callback("change_where") {|action_context, params|
      @where = params
    }

    @dwg_export_dialog.add_action_callback("change_fileformat") {|action_context, params|
      @fileformat = params
    }

    @dwg_export_dialog.add_action_callback("dialog_ready") {|action_context, params|
      load_scenes
      set_selects
      disable_suffixes
      @export = false

      @dwg_export_dialog.execute_script("resize_dialog()")
    }

    @dwg_export_dialog.add_action_callback("resize_dialog") {|action_context, params|
      params = params.split(';')
      w = params[0].to_i
      h = params[1].to_i
    }

    @dwg_export_dialog.add_action_callback("cancel") {|action_context, params|
      @export = true
      @export_scenes = false
      @dwg_export_dialog.close
    }

    @dwg_export_dialog.add_action_callback("export") {|action_context, params|
      @dwg_export_dialog.close
      write_export_scene_list
      save_selects

      if export_scene_list.size == 0 && @export_type == 'Scenes'
        UI.messagebox('No scenes selected to export.')
        @export_scenes = false
      else
        @export_scenes = true
      end
      @export = true
    }

    @dwg_export_dialog.set_on_closed {
      unless @export
        @export_scenes = false
        Skalp::exportDWGbutton_off
      end
    }

    @dwg_export_dialog.add_action_callback("scene_selected") {|action_context, params|
      vars = params.split(';')
      name = vars[0]
      status = vars[1]

      if (status.to_s == 'true') then
        status = 'true'
      else
        status = 'false'
      end

      @scene_status[name] = status
    }

    @dwg_export_dialog.show_modal
  end

  def self.disable_suffixes
    if @section_layer == 'fixed'
      @dwg_export_dialog.execute_script("disable_input('section_suffix', true)")
      @dwg_export_dialog.execute_script("disable_input('label_section_suffix', true)")
    else
      @dwg_export_dialog.execute_script("disable_input('section_suffix', false)")
      @dwg_export_dialog.execute_script("disable_input('label_section_suffix', false)")
    end

    if @forward_layer == 'fixed'
      @dwg_export_dialog.execute_script("disable_input('forward_suffix', true)")
      @dwg_export_dialog.execute_script("disable_input('label_forward_suffix', true)")
    else
      @dwg_export_dialog.execute_script("disable_input('forward_suffix', false)")
      @dwg_export_dialog.execute_script("disable_input('label_forward_suffix', false)")
    end

    if @rear_layer == 'fixed'
      @dwg_export_dialog.execute_script("disable_input('rear_suffix', true)")
      @dwg_export_dialog.execute_script("disable_input('label_rear_suffix', true)")
    else
      @dwg_export_dialog.execute_script("disable_input('rear_suffix', false)")
      @dwg_export_dialog.execute_script("disable_input('label_rear_suffix', false)")
    end
  end

  def self.set_selects
    @section_layer = Sketchup.read_default('Skalp_export', 'section_layer') || "object"
    @section_suffix = Sketchup.read_default('Skalp_export', 'section_suffix') || "-S"
    @hatch_suffix = Sketchup.read_default('Skalp_export', 'hatch_suffix') || "-SH"
    @fill_suffix = Sketchup.read_default('Skalp_export', 'fill_suffix') || "-SF"
    @forward_layer = Sketchup.read_default('Skalp_export', 'forward_layer') || "layers"
    @forward_suffix = Sketchup.read_default('Skalp_export', 'forward_suffix') || "-F"
    @forward_color = Sketchup.read_default('Skalp_export', 'forward_color') || "black"
    @rear_layer = Sketchup.read_default('Skalp_export', 'rear_layer') || "layers"
    @rear_suffix = Sketchup.read_default('Skalp_export', 'rear_suffix') || "-R"
    @rear_color = Sketchup.read_default('Skalp_export', 'rear_color') || "black"

    @fileformat = Sketchup.read_default('Skalp_export', 'fileformat') || "ac2018"
    @where = Sketchup.read_default('Skalp_export', 'where') || "model"

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
    Sketchup.write_default('Skalp_export', 'section_layer', @section_layer)
    Sketchup.write_default('Skalp_export', 'section_suffix', @section_suffix)
    Sketchup.write_default('Skalp_export', 'fill_suffix', @fill_suffix)
    Sketchup.write_default('Skalp_export', 'hatch_suffix', @hatch_suffix)
    Sketchup.write_default('Skalp_export', 'forward_layer', @forward_layer)
    Sketchup.write_default('Skalp_export', 'forward_suffix', @forward_suffix)
    Sketchup.write_default('Skalp_export', 'forward_color', @forward_color)
    Sketchup.write_default('Skalp_export', 'rear_layer', @rear_layer)
    Sketchup.write_default('Skalp_export', 'rear_suffix', @rear_suffix)
    Sketchup.write_default('Skalp_export', 'rear_color', @rear_color)

    Sketchup.write_default('Skalp_export', 'fileformat', @fileformat)
    Sketchup.write_default('Skalp_export', 'where', @where)

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
      @export_type = 'Scenes'
      selected = @scene_status[page.name]
      unless selected
        selected = 'false'
        @scene_status[page.name] = selected
      end
      add_scene_to_dialog(page.name, selected)
    end

    if Skalp.active_model.skpModel.pages.count == 0
      @export_type = 'Active View'
      add_scene_to_dialog('Active View', 'true')
    end

    #@dwg_export_dialog.execute_script("reset_table_size()")
  end

  def self.add_scene_to_dialog(scenename, selected)
    (selected == 'true') ? checked = 'checked' : checked = ''

    script = <<-SCRIPT
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
      pages_list << page if page && status == 'true'
    end

    pages_list
  end

  def self.read_export_scene_list
    attrib = Skalp.active_model.skpModel.get_attribute('Skalp_4', 'export_scenes')
    @scene_status = Hash.new
    if attrib.class == String && eval(attrib).class == Hash
      @scene_status = eval(attrib)
    else
      Skalp.active_model.skpModel.pages.each do |page|
        @scene_status[page.name] = 'false'
      end
    end
  end

  def self.write_export_scene_list
    Skalp.active_model.start('Skalp - save export scenes list')
    Skalp.active_model.skpModel.set_attribute('Skalp_4', 'export_scenes', @scene_status.to_s)
    Skalp.active_model.commit
  end
end