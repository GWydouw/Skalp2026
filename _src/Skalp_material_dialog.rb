module Skalp
  module Material_dialog
    require 'json'

    CACHE_DIR = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp/resources/temp/"

    class << self
      attr_accessor :materialdialog, :selected_material, :active_library, :external_callback
    end

    def self.setup_dialog(library_actions = true)
      @library_actions = library_actions
      x = Sketchup.read_default('Skalp_Paint_dialog', 'x')
      y = Sketchup.read_default('Skalp_Paint_dialog', 'y')
      w = Sketchup.read_default('Skalp_Paint_dialog', 'w')
      h = Sketchup.read_default('Skalp_Paint_dialog', 'h')

      x = 50 unless x
      y = 50 unless y
      w = 206 unless w
      h = 398 unless h

      @materialdialog = UI::HtmlDialog.new(
          {
              :dialog_title => "Skalp Materials",
              :preferences_key => "com.skalp_materials.plugin",
              :scrollable => true,
              :resizable => true,
              :width => w,
              :height => h,
              :left => x,
              :top => y,
              :min_width => 198,
              :min_height => 250,
              :max_width => 1000,
              :max_height => 1000,
              :style => UI::HtmlDialog::STYLE_UTILITY
          }) unless @materialdialog

      unless Sketchup.read_default('Skalp_Paint_dialog', 'x')
        Sketchup.write_default('Skalp_Paint_dialog', 'x', x)
        Sketchup.write_default('Skalp_Paint_dialog', 'y', y)
        Sketchup.write_default('Skalp_Paint_dialog', 'w', w)
        Sketchup.write_default('Skalp_Paint_dialog', 'h', h)
      end

      html_file = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp/html/material_dialog.html"
      @materialdialog.set_file(html_file)
      @materialdialog.set_on_closed {
        @materialdialog = nil
        Sketchup.active_model.select_tool(nil) if Sketchup.active_model
        }

      @materialdialog.add_action_callback("dialog_ready") { |action_context, params|
        load_dialog
        unless @return_webdialog
          @selected_material ='Skalp default'
          @materialdialog.execute_script("select('Skalp default');")
        end

        if @library_actions
          @materialdialog.execute_script("hide_library_actions();")
        end
      }

      @materialdialog.add_action_callback("dialog_focus") { |action_context, params|
        unless Sketchup.active_model
          Skalp::stop_skalp
        end
      }

      @materialdialog.add_action_callback("su_focus") { |action_context, params|
        focus_back if OS == :MAC && @materialdialog.visible?
      }

      @materialdialog.add_action_callback("material_menu") { |action_context, action|
        if action == 'remove'
          if @active_library == 'Skalp materials in model'
            Skalp::delete_skalp_material(@selected_material)
          else
            Skalp::Material_dialog.delete_material_from_library(@active_library, @selected_material)
            Skalp::Material_dialog.create_thumbnails(@active_library)
          end
        elsif action == 'move' && @active_library != 'Skalp materials in model'
          libraries = Dir.glob(File.join(Skalp::MATERIAL_PATH, '*.json')).map { |f| File.basename(f, '.json') }
          target = UI.inputbox(["Move to library:"], [libraries.first], [libraries.join('|')], "Move Material")
          if target && target[0] != @active_library
            move_material_between_libraries(@active_library, target[0], @selected_material)
            Skalp::Material_dialog.create_thumbnails(@active_library)
          end
        elsif action == 'rename' && @active_library != 'Skalp materials in model'
          Skalp.rename_material_in_library(@active_library, @selected_material)
          Skalp::Material_dialog.create_thumbnails(@active_library)
        elsif action == 'copy'
          Skalp::save_pattern_to_library(@selected_material)
        elsif @active_library == 'Skalp materials in model'
          case action
          when 'edit'
            Skalp::edit_skalp_material(@selected_material)
          when 'add'
            Skalp::create_new_skalp_material
          when 'export'
            Skalp::export_material_textures(true)
          when 'save_all'
            Skalp::save_all_skalp_materials_to_new_library
          end
        else
          UI.messagebox('These functions only work on Skalp materials inside the model.')
        end
      }

      @materialdialog.add_action_callback("library_menu") { |action_context, action|
        case action
        when 'new'
          Skalp::create_library
          load_libraries
        end
      }

      @materialdialog.add_action_callback("library") { |action_context, library|
        create_thumbnails(library)
      }

      @materialdialog.add_action_callback("position") { |action_context, x, y, w, h|
        if !@return_webdialog && w > 1
          Sketchup.write_default('Skalp_Paint_dialog', 'x', x)
          Sketchup.write_default('Skalp_Paint_dialog', 'y', y)
          Sketchup.write_default('Skalp_Paint_dialog', 'w', w)
          Sketchup.write_default('Skalp_Paint_dialog', 'h', h)
        end
      }

      @materialdialog.add_action_callback("window_size") { |action_context, w, h|
        @window_width = w.to_i
        @window_height = h.to_i
      }

      @materialdialog.add_action_callback("select") { |action_context, materialname|
        if materialname == 'none'
          materialname = ''
        elsif !Sketchup.active_model.materials[materialname]
          create_sectionmaterial_from_library(@active_library_materials[materialname])
        end
        if @return_webdialog
          if @return_webdialog == Skalp.dialog.webdialog && @id == "model_material"
            materialname = 'Skalp default' if materialname == ''
            @return_webdialog.execute_script("$('##{@id}').val('#{materialname}')")
            Skalp.style_update = true
            @return_webdialog.execute_script("save_style(false)")
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.dialog.webdialog && @id == 'material_list'
            @return_webdialog.execute_script("$('##{@id}').val('#{materialname}')")
            Skalp::dialog.define_sectionmaterial(materialname)
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.dialog.webdialog && @id != "model_material"
            @return_webdialog.execute_script("$('##{@id}').val('#{materialname}')")
            @return_webdialog.execute_script("highlight($('##{@id}'), true)")
            Skalp.style_update = true
            @return_webdialog.execute_script("$('##{@id}').change()")
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.layers_dialog
            Skalp.define_layer_material(Skalp.layers_hash[@id], materialname) if Skalp.layers_hash[@id]
            Skalp.update_layers_dialog
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.hatch_dialog.webdialog
            if Sketchup.active_model.materials[materialname] && Sketchup.active_model.materials[materialname].get_attribute('Skalp', 'ID')
              Skalp.hatch_dialog.material_selector_status = true
              @return_webdialog.execute_script("$('#material_list').val('#{materialname}')")
              Skalp.style_update = true
              @return_webdialog.execute_script("$('#material_list').change()")
              @materialdialog.close if @return_webdialog
            end
          end
        else
          @selected_material = materialname
          if @external_callback
            @external_callback.call(materialname)
            @external_callback = nil
            @materialdialog.close
          end
        end
      }

      if @return_webdialog
        @materialdialog.set_position(@x.to_i + 50, @y.to_i + 50)
        @materialdialog.bring_to_front
        @materialdialog.show_modal
      else
        section_x = Sketchup.read_default('Skalp', 'sections_x').to_i
        section_y = Sketchup.read_default('Skalp', 'sections_y').to_i
        section_w = Sketchup.read_default('Skalp', 'sections_w').to_i

        if Skalp.dialog.showmore_dialog
          section_h = Sketchup.read_default('Skalp', 'height_expand_resize')
        else
          section_h = 100
        end

        x = Sketchup.read_default('Skalp_Paint_dialog', 'x').to_i
        y = Sketchup.read_default('Skalp_Paint_dialog', 'y').to_i
        w = Sketchup.read_default('Skalp_Paint_dialog', 'w').to_i
        h = Sketchup.read_default('Skalp_Paint_dialog', 'h').to_i

        if ((x+w) < section_x) || (x > (section_x + section_w)) || (y > (section_y + section_h)) || ((y+h) < section_y)
          @materialdialog.set_position(x, y)
        else
          if w < section_x
            new_x = ((section_x - w)/2).to_i
          else
            new_x = section_x + section_w + 50
          end

          @materialdialog.set_position(new_x, 100)
        end

        @materialdialog.show
      end
    end

    def self.show_dialog(x = 100, y = 100, webdialog = nil, id = "")
      @return_webdialog = webdialog
      @id = id
      @x = x
      @y = y
      if id == ""
        setup_dialog(false)
      else
        setup_dialog(true)
      end
    end

    # Dirty method to get the focus back
    def self.focus_back
      html = <<-EOT
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
<script>
    function loaded(){
        sketchup.su_focus();
    }

</script>
</head>

<body onload="loaded()" >
<div>
    <span>SketchUp dommie dialog</span>
</div>
</body>
</html>

      EOT
      options = {
          :dialog_title => "Material",
          :preferences_key => "Skalp.dummie",
          :width => 1,
          :height => 1,
          :left => 0,
          :top => 0,
          :style => UI::HtmlDialog::STYLE_DIALOG  # New feature!
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_html(html)
      dialog.center # New feature!
      dialog.add_action_callback('su_focus') { |action_context, name, num_pokes|
        dialog.close
      }
      dialog.show
    end

    def self.load_dialog
      load_libraries
      create_thumbnails('Skalp materials in model')
    end

    def self.update_dialog
      create_thumbnails(@active_library)
    end

    def self.close_dialog
      @materialdialog.close if @materialdialog
    end

    def self.load_libraries
      libraries = ['SketchUp materials in model', 'Skalp materials in model']

      active_dir = Dir.pwd
      Dir.chdir(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp/resources/materials/")
      Dir.glob('*.json') do |library|
        libraries << library.gsub('.json', '')
      end
      Dir.chdir(active_dir)

      @materialdialog.execute_script("load_libraries(#{libraries.to_json})")
    end

    def self.add_material(name, image_top, text_top, source)
      @materials << name
      @materials << image_top
      @materials << text_top
      @materials << source
    end

    def self.create_thumbnails(lib = 'Skalp materials in model')
      @active_library = lib
      @materials = []

      case lib
      when 'Skalp materials in model'
        type = true
        # Ensure PNG blobs for model materials before creating the cache
        Skalp.ensure_png_blobs_for_model_materials if Skalp.respond_to?(:ensure_png_blobs_for_model_materials)
        materials = Skalp.create_thumbnails_cache(true)
        sorted_materials = materials.keys.sort_by(&:downcase)
        append_thumbnail("#{Skalp.translate('none')}", '', false, 0)

        n = 1
        sorted_materials.each do |material|
          append_thumbnail(material, materials[material], true, n)
          n += 1
        end

      when 'SketchUp materials in model'
        type = false

        sorted_materials = []
        materials = Sketchup.active_model.materials
        materials.each {|mat| sorted_materials << mat.name unless mat.get_attribute('Skalp', 'ID')}

        n = 0
        sorted_materials.sort_by(&:downcase).each { |material|
            file = Skalp::THUMBNAIL_PATH + material.to_s + '.png'
            materials[material].write_thumbnail(file, 54)
            append_SU_thumbnail(material, file, false, n)
            n += 1
        }
      else
        type = true
        append_thumbnails_from_library(lib)
      end

      @materialdialog.execute_script("load_materials(#{type}, #{@materials})")

      unless @return_webdialog
        @materialdialog.execute_script("unselect()")
      end
    end

    def self.append_thumbnail(materialname, path, png_blob = false, order = 1)
      top = 23 * order
      png_blob ? source = "data:image/png;base64,#{path}" : source = path
      add_material(materialname, top, top+2, source)
    end

    def self.append_SU_thumbnail(materialname, path, png_blob = false, order = 1)
      top = 23 * order
      png_blob ? source = "data:image/png;base64,#{path}" : source = path
      add_material(materialname, top+2, top+2, source)
    end

    def self.append_thumbnails_from_library(lib)
      return unless lib
      json_file = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp/resources/materials/" + lib + ".json"
      return unless File.exist?(json_file)

      @active_library_materials = {}
      materials = {}

      json_data = JSON.parse(File.read(json_file)) rescue []
      json_data.each do |pattern_info|
        next unless pattern_info["name"].is_a?(String) && pattern_info["png_blob"]
        @active_library_materials[pattern_info["name"]] = pattern_info.transform_keys(&:to_sym)
        materials[pattern_info["name"]] = pattern_info["png_blob"]
      end

      sorted_materials = materials.keys.sort_by(&:downcase)
      n = 0
      sorted_materials.each do |material|
        append_thumbnail(material, materials[material], true, n)
        n += 1
      end
    end

    def self.create_sectionmaterial_from_library(pattern_info)
      Skalp::block_color_by_layer = true

      if pattern_info[:line_color].nil? && pattern_info[:line_color].nil? && color_from_name(pattern_info[:name])
        pattern_info[:line_color] = color_from_name(pattern_info[:name])
        pattern_info[:fill_color] = color_from_name(pattern_info[:name])
      end

      if pattern_info[:line_color] && !pattern_info[:line_color].include?('rgb')
        pattern_info[:line_color] = color_from_name(pattern_info[:line_color]) || 'rgb(0,0,0)'
      end

      if pattern_info[:fill_color] && !pattern_info[:fill_color].include?('rgb')
        pattern_info[:fill_color] = color_from_name(pattern_info[:fill_color]) || 'rgb(255,255,255)'
      end

      pattern_info[:line_color] = pattern_info[:fill_color] if pattern_info[:fill_color] && pattern_info[:line_color].nil?

      pattern_definition = {
        name: 'no_name',
        pattern:   ["*ANSI31, ANSI IRON, BRICK, STONE MASONRY","45, 0,0, 0,.125"],
        pattern_size: '3mm',
        line_color: 'rgb(0,0,0)',
        fill_color: 'rgb(255,255,255)',
        pen: 0.0071,
        section_cut_width: 0.0071,
        alignment: false
      }.merge(pattern_info)

      if pattern_definition[:pattern][0].include?('*')
        pattern = pattern_definition[:pattern]
      else
        pattern = ["*#{pattern_definition[:name]}"] + pattern_definition[:pattern]
      end

      pattern_info[:pattern] = pattern

      pattern_definition[:alignment] ? alignment_string = "true" : alignment_string = "false"

      pattern_string = {:name => pattern_definition[:name],
                        :pattern => pattern,
                        :print_scale => 1,
                        :resolution => 600,
                        :user_x => pattern_definition[:pattern_size],
                        :space => :paperspace,
                        :line_color => pattern_definition[:line_color],
                        :fill_color => pattern_definition[:fill_color],
                        :pen => pattern_definition[:pen], #0.18mm
                        :section_cut_width => pattern_definition[:section_cut_width], #0.35mm
                        :alignment => alignment_string
      }

      Skalp.active_model ? Skalp.active_model.start("Skalp - #{Skalp.translate('Create Skalp material')}", true) : Sketchup.active_model.start_operation("Skalp - #{Skalp.translate('Create Skalp material')}", true, false, false)

      hatch = SkalpHatch::Hatch.new
      hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(pattern_string[:pattern]))

      tile = Tile_size.new()
      tile.calculate(pattern_string[:user_x], :x)

      create_png_result = hatch.create_png({
                                               :type => :tile,
                                               :line_color => pattern_string[:line_color],
                                               :fill_color => pattern_string[:fill_color],
                                               :pen => pattern_string[:pen], # pen_width in inch (1pt = 1.0 / 72)
                                               :resolution => Hatch_dialog::PRINT_DPI,
                                               :print_scale => 1,
                                               :user_x => tile.x_value,
                                               :space => pattern_string[:space]
                                           })

      pattern_string[:pattern] = create_png_result[:original_definition]
      pattern_string[:user_x] = tile.x_string
      pattern_hash = pattern_string.merge(create_png_result)
      pattern_hash.delete(:original_definition)

      Sketchup.active_model.materials[pattern_hash[:name]] ? hatch_material = Sketchup.active_model.materials[pattern_hash[:name]] : hatch_material = Sketchup.active_model.materials.add(pattern_hash[:name])

      hatch_material.texture = IMAGE_PATH + 'tile.png'
      hatch_material.texture.size = hatch.tile_width / Hatch_dialog::PRINT_DPI
      hatch_material.metalness_enabled = false
      hatch_material.normal_enabled = false

      Skalp.set_ID(hatch_material)
      pattern_hash[:pattern] = ["*#{pattern_hash[:name]}"] + pattern_hash[:pattern] unless pattern_hash[:pattern][0].include?('*')
      Skalp.set_pattern_info_attribute(hatch_material, pattern_hash)

      Skalp.active_model ? Skalp.active_model.commit : Sketchup.active_model.commit_operation
      Skalp::block_color_by_layer = false
    end

    def self.delete_material_from_library(library, materialname)
      json_path = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp/resources/materials/#{library}.json"
      return unless File.exist?(json_path)

      json_data = JSON.parse(File.read(json_path)) rescue []
      json_data.reject! { |info| info["name"] == materialname }

      File.write(json_path, JSON.pretty_generate(json_data))
    end
  end
end

# Add the ensure_png_blobs_for_model_materials method to the Skalp module (if not already present)
module Skalp
  def self.ensure_png_blobs_for_model_materials
    Sketchup.active_model.materials.each do |material|
      next unless material.get_attribute('Skalp', 'ID')
      info_string = material.get_attribute('Skalp', 'pattern_info')
      next unless info_string

      pattern_info = eval(info_string) rescue nil
      next unless pattern_info.is_a?(Hash)

      unless pattern_info[:png_blob]
        png_blob = Skalp::create_thumbnail(pattern_info, 81, 27) rescue nil
        if png_blob
          pattern_info[:png_blob] = png_blob
          material.set_attribute('Skalp', 'pattern_info', pattern_info.inspect)
        end
      end
    end
  end
end