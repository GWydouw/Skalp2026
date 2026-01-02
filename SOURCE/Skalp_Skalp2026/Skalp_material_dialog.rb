module Skalp
  module Material_dialog
    require "json"
    require "fileutils"
    Sketchup.require(File.join(File.dirname(__FILE__), "Skalp_material_dialog_helpers"))

    CACHE_DIR = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/resources/temp/"

    class << self
      attr_accessor :materialdialog, :selected_material, :active_library, :external_callback
    end

    def self.show_dialog(x = nil, y = nil, webdialog = nil, id = nil, library_actions = nil)
      @return_webdialog = webdialog
      @id = id

      # If library_actions not specified, hide it when in picker mode (webdialog present)
      @library_actions = if library_actions.nil?
                           webdialog.nil?
                         else
                           library_actions
                         end

      x_cached = Sketchup.read_default("Skalp_Paint_dialog", "x")
      y_cached = Sketchup.read_default("Skalp_Paint_dialog", "y")
      w = Sketchup.read_default("Skalp_Paint_dialog", "w")
      h = Sketchup.read_default("Skalp_Paint_dialog", "h")

      x = x_cached if x.nil? || x.is_a?(TrueClass) || x.is_a?(FalseClass)
      y = y_cached if y.nil? || y.is_a?(TrueClass) || y.is_a?(FalseClass)
      x ||= 50
      y ||= 50
      w ||= 206
      h ||= 398

      # If in Picker Mode (no library actions), reduce height slightly to account for hidden footer
      # or just leave it to show more materials. User asked to "remove the zone".
      # Hiding the footer via JS removes the zone visually (content expands).
      # If we want to shrink the window, we can do it here:
      # h -= 35 if !@library_actions

      @materialdialog ||= UI::HtmlDialog.new(
        {
          dialog_title: "Skalp Materials",
          preferences_key: "com.skalp_materials.plugin",
          scrollable: true,
          resizable: true,
          width: w,
          height: h,
          left: x,
          top: y,
          min_width: 198,
          min_height: 250,
          max_width: 1000,
          max_height: 1000,
          style: UI::HtmlDialog::STYLE_UTILITY
        }
      )

      unless Sketchup.read_default("Skalp_Paint_dialog", "x")
        Sketchup.write_default("Skalp_Paint_dialog", "x", x)
        Sketchup.write_default("Skalp_Paint_dialog", "y", y)
        Sketchup.write_default("Skalp_Paint_dialog", "w", w)
        Sketchup.write_default("Skalp_Paint_dialog", "h", h)
      end

      html_file = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/material_dialog.html"
      @materialdialog.set_file(html_file)
      @materialdialog.set_on_closed do
        @materialdialog = nil
        Skalp.patterndesignerbutton_off
        Sketchup.active_model.select_tool(nil) if Sketchup.active_model
      end

      @materialdialog.add_action_callback("dialog_ready") do |action_context, params|
        load_dialog
        unless @return_webdialog
          # Use selected_material if already set, otherwise default
          material_to_select = @selected_material || "Skalp default"
          @selected_material = material_to_select
          @materialdialog.execute_script("select('#{material_to_select}');") if @materialdialog
        end

        if @library_actions
          # Ensure it's shown? Default CSS is shown.
        else
          @materialdialog.execute_script("hide_library_actions();")
        end
      end

      @materialdialog.add_action_callback("refresh") do |action_context|
        load_dialog
      end

      @materialdialog.add_action_callback("open_context_menu") do |action_context, materialname|
        # Check if context menu logic is needed here or in JS
      end

      @materialdialog.add_action_callback("library") do |action_context, libraryname|
        @active_library = libraryname
        create_thumbnails(libraryname)
      end

      @materialdialog.add_action_callback("material_menu") do |action_context, action, materialname|
        case action
        when "create_new"
          Skalp.edit_material_pattern("Skalp Pattern") if Skalp.respond_to?(:edit_material_pattern)
        when "create_new_based_on"
          # materialname = source material
          source_data = Sketchup.active_model.get_attribute("Skalp_sectionmaterials", materialname)
          if source_data
            new_name = "#{materialname} (Copy)"
            count = 1
            # Check for name collision in Skalp attributes or Model materials
            while Sketchup.active_model.get_attribute("Skalp_sectionmaterials",
                                                      new_name) || Sketchup.active_model.materials[new_name]
              count += 1
              new_name = "#{materialname} (Copy #{count})"
            end

            Sketchup.active_model.set_attribute("Skalp_sectionmaterials", new_name, source_data)
            Skalp.edit_material_pattern(new_name) if Skalp.respond_to?(:edit_material_pattern)
          else
            UI.messagebox("Error: Could not read source material data for '#{materialname}'")
          end
        when "edit"
          Skalp.edit_material_pattern(materialname) if Skalp.respond_to?(:edit_material_pattern)
        when "remove"
          if Skalp.respond_to?(:delete_skalp_material)
            Skalp.delete_skalp_material(materialname, @active_library)
          else
            # Fallback
            delete_material_from_library(@active_library, materialname)
            create_thumbnails(@active_library)
          end
        when "paint_to_section"
          Skalp::Material_dialog.selected_material = materialname
          # Activate Skalp Paint tool
          Sketchup.active_model.select_tool(Skalp.skalp_paint) if Skalp.skalp_paint
          Skalp.paintbucketbutton_on if Skalp.respond_to?(:paintbucketbutton_on)
        when "move"
          if Skalp.respond_to?(:save_pattern_to_library)
            saved_path = Skalp.save_pattern_to_library(materialname)
            if saved_path
              # Switch to new library
              new_lib_name = File.basename(saved_path, ".skp")

              # Delete from old library
              if ["Skalp materials in model", "SketchUp materials in model"].include?(@active_library)
                Skalp.delete_skalp_material(materialname, @active_library) if Skalp.respond_to?(:delete_skalp_material)
              else
                delete_material_from_library(@active_library, materialname)
              end

              # Reload
              load_libraries
              @active_library = new_lib_name
              @materialdialog.execute_script("library('#{new_lib_name}')")
              create_thumbnails(@active_library)
            end
          end
        when "copy"
          Skalp.save_pattern_to_library(materialname) if Skalp.respond_to?(:save_pattern_to_library)
          load_libraries
          create_thumbnails(@active_library)
        when "duplicate"
          if ["Skalp materials in model", "SketchUp materials in model"].include?(@active_library)
            mat = Sketchup.active_model.materials[materialname]
            if mat
              Skalp.inputbox_custom(["New Name"], ["#{materialname} copy"], "Duplicate Material") do |new_name|
                if new_name && !new_name[0].empty?
                  new_mat = Sketchup.active_model.materials.add(new_name[0])
                  new_mat.texture = mat.texture
                  new_mat.color = mat.color
                  new_mat.alpha = mat.alpha
                  if mat.attribute_dictionaries
                    mat.attribute_dictionaries.each do |dict|
                      next if dict.name == "Skalp_memory_attributes"

                      dict.each do |k, v|
                        new_mat.set_attribute(dict.name, k, v)
                      end
                    end
                  end
                  create_thumbnails(@active_library)
                end
              end
            end
          else
            Skalp::Material_dialog.duplicate_material_in_library(@active_library, materialname)
          end
        when "replace_confirmed"
          # ... existing code ...
        when "merge"
        # ... existing code ...
        when "rename"
          if ["Skalp materials in model", "SketchUp materials in model"].include?(@active_library)
            mat = Sketchup.active_model.materials[materialname]
            if mat
              Skalp.inputbox_custom(["New name"], [materialname], "Rename Material") do |new_name|
                if new_name && !new_name[0].empty?
                  begin
                    mat.name = new_name[0]
                    create_thumbnails(@active_library)
                  rescue ArgumentError => e
                    UI.messagebox("Name already exists or is invalid. Please choose another name.")
                  end
                end
              end
            end
          elsif Skalp.respond_to?(:rename_material_in_library)
            Skalp.rename_material_in_library(@active_library,
                                             materialname)
          end
        when "save_all"
          Skalp.save_all_skalp_materials_to_new_library if Skalp.respond_to?(:save_all_skalp_materials_to_new_library)
        when "export"
          Skalp.export_skalp_materials if Skalp.respond_to?(:export_skalp_materials)
        when "merge"
          # Merge logic if exists
        end
      end

      @materialdialog.add_action_callback("library_menu") do |action_context, action|
        case action
        when "new"
          if Skalp.respond_to?(:create_library)
            Skalp.create_library do |new_lib|
              load_libraries
              if new_lib
                @active_library = new_lib
                @materialdialog.execute_script("library('#{new_lib}')")
                create_thumbnails(@active_library)
              end
            end
          end
        when "rename"
        when "rename"
          Skalp::Material_dialog.rename_library(@active_library)
        when "delete"
          if Skalp::Material_dialog.delete_library(@active_library)
            load_libraries
            @active_library = "Skalp materials in model"
            @materialdialog.execute_script("library('Skalp materials in model')")
            create_thumbnails(@active_library)
          end
        end
      end

      @materialdialog.add_action_callback("select") do |action_context, materialname|
        if materialname == "none"
          materialname = ""
        elsif !Sketchup.active_model.materials[materialname]
          if @active_library_materials
            Skalp::Material_dialog.create_sectionmaterial_from_library(@active_library_materials[materialname])
          end
        end
        if @return_webdialog
          if @return_webdialog == Skalp.dialog.webdialog && @id == "model_material"
            materialname = "Skalp default" if materialname == ""
            @return_webdialog.execute_script("$('##{@id}').val('#{materialname}')")
            Skalp.style_update = true
            @return_webdialog.execute_script("save_style(false)")
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.dialog.webdialog && @id == "material_list"
            @return_webdialog.execute_script("$('##{@id}').val('#{materialname}')")
            Skalp.dialog.define_sectionmaterial(materialname)
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.dialog.webdialog && @id != "model_material"
            @return_webdialog.execute_script("$('##{@id}').val('#{materialname}')")
            @return_webdialog.execute_script("highlight($('##{@id}'), true)")
            Skalp.style_update = true
            @return_webdialog.execute_script("$('##{@id}').change()")
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.layers_dialog
            # Updated to match new HtmlDialog handling in Skalp_UI: the caller passes us the reference
            if @id.to_s.include?(";")
              Skalp.define_batch_layer_materials(@id, materialname)
            elsif Skalp.layers_hash[@id]
              Skalp.define_layer_material(Skalp.layers_hash[@id], materialname)
            end
            Skalp.update_layers_dialog # This updates the new HtmlDialog
            @materialdialog.close if @return_webdialog
          elsif @return_webdialog == Skalp.hatch_dialog.webdialog
            if Sketchup.active_model.materials[materialname] && Sketchup.active_model.materials[materialname].get_attribute(
              "Skalp", "ID"
            )
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
      end

      if @return_webdialog
        @materialdialog.set_position(@x.to_i + 50, @y.to_i + 50)
        @materialdialog.bring_to_front
        @materialdialog.show
      else
        section_x = Sketchup.read_default("Skalp", "sections_x").to_i
        section_y = Sketchup.read_default("Skalp", "sections_y").to_i
        section_w = Sketchup.read_default("Skalp", "sections_w").to_i

        section_h = if Skalp.dialog.showmore_dialog
                      Sketchup.read_default("Skalp", "height_expand_resize")
                    else
                      100
                    end

        x = Sketchup.read_default("Skalp_Paint_dialog", "x").to_i
        y = Sketchup.read_default("Skalp_Paint_dialog", "y").to_i
        w = Sketchup.read_default("Skalp_Paint_dialog", "w").to_i
        h = Sketchup.read_default("Skalp_Paint_dialog", "h").to_i

        if @materialdialog.visible?
          @materialdialog.bring_to_front
          return
        end

        if ((x + w) < section_x) || (x > (section_x + section_w)) || (y > (section_y + section_h)) || ((y + h) < section_y)
          @materialdialog.set_position(x, y)
        else
          new_x = if w < section_x
                    ((section_x - w) / 2).to_i
                  else
                    section_x + section_w + 50
                  end

          @materialdialog.set_position(new_x, 100)
        end

        @materialdialog.show
      end
    end

    def self.load_dialog
      load_libraries
      create_thumbnails
    end

    def self.update_dialog
      create_thumbnails(@active_library)
    end

    def self.close_dialog
      @materialdialog.close if @materialdialog
    end

    def self.load_libraries
      return unless @materialdialog

      libraries = ["Skalp materials in model", "SketchUp materials in model"]
      match = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/resources/materials/*.json"
      Dir[match].each do |file|
        libraries << File.basename(file, ".json")
      end
      @materialdialog.execute_script("load_libraries(#{libraries.to_json})")
    end

    # ...
    def self.add_material(name, image_top, text_top, source)
      @materials << name
      @materials << source
    end

    def self.create_thumbnails(lib = "Skalp materials in model")
      @active_library = lib
      @materials = []

      case lib
      when "Skalp materials in model"
        type = true
        materials = Skalp.create_thumbnails_cache(true)
        sorted_materials = materials.keys.sort_by(&:downcase)

        none_blob = create_none_thumbnail
        append_thumbnail("#{Skalp.translate('none')}", none_blob, true, 0)

        n = 1
        sorted_materials.each do |material|
          append_thumbnail(material, materials[material], true, n)
          n += 1
        end

      when "SketchUp materials in model"
        type = false

        sorted_materials = []
        materials = Sketchup.active_model.materials
        materials.each { |mat| sorted_materials << mat.name unless mat.get_attribute("Skalp", "ID") }

        n = 0
        sorted_materials.sort_by(&:downcase).each do |material|
          file = Skalp::THUMBNAIL_PATH + material.to_s + ".png"
          materials[material].write_thumbnail(file, 54) unless File.exist?(file)
          append_SU_thumbnail(material, file, false, n)
          n += 1
        end
      else
        type = true
        append_thumbnails_from_library(lib)
      end

      return unless @materialdialog

      @materialdialog.execute_script("load_materials(#{type}, #{@materials.to_json})")

      return if @return_webdialog

      return unless @materialdialog

      @materialdialog.execute_script("unselect()")
    end

    def self.append_thumbnail(materialname, path, png_blob = false, order = 1)
      # No position calculation needed
      source = png_blob ? "data:image/png;base64,#{path}" : path
      add_material(materialname, 0, 0, source)
    end

    def self.append_SU_thumbnail(materialname, path, png_blob = false, order = 1)
      source = png_blob ? "data:image/png;base64,#{path}" : path
      add_material(materialname, 0, 0, source)
    end

    def self.append_thumbnails_from_library(lib)
      return unless lib

      json_file = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/resources/materials/" + lib + ".json"
      return unless File.exist?(json_file)

      @active_library_materials = {}
      materials = {}

      json_data = begin
        JSON.parse(File.read(json_file))
      rescue StandardError
        []
      end
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
      return unless pattern_info && pattern_info[:name]

      material_name = pattern_info[:name]
      Sketchup.active_model.set_attribute("Skalp_sectionmaterials", material_name, pattern_info.inspect)
      Skalp.create_sectionmaterial(material_name)
    end

    def self.create_none_thumbnail
      # 54x18 standard size
      require "base64"

      # Path to the old grey skalp logo
      logo_path = File.join(Skalp::SKALP_PATH, "html/icons/skalp_empty.png")
      puts "Skalp Debug: create_none_thumbnail logo_path: #{logo_path}" if defined?(DEBUG) && DEBUG
      puts "Skalp Debug: logo_path exists? #{File.exist?(logo_path)}" if defined?(DEBUG) && DEBUG

      if logo_path && File.exist?(logo_path)
        Base64.encode64(File.binread(logo_path)).gsub("\n", "")
      else
        # Fallback to dynamic drawing if file missing
        # Try to load ChunkyPNG if not defined
        unless defined?(ChunkyPNG)
          png_lib = Sketchup.find_support_file("chunky_png.rb", "Plugins/Skalp_Skalp2026/chunky_png/lib")
          require png_lib if png_lib
        end

        if defined?(ChunkyPNG)
          png = ChunkyPNG::Image.new(54, 18, ChunkyPNG::Color::WHITE)
          border = ChunkyPNG::Color.rgb(200, 200, 200)
          png.rect(0, 0, 53, 17, border)
          # Draw a simple grey box/logo placeholder
          grey = ChunkyPNG::Color.rgb(200, 200, 200)
          png.rect(10, 4, 43, 13, grey, grey)
          Base64.encode64(png.to_blob).gsub("\n", "")
        else
          # Final fallback to 1x1 transparent
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        end
      end
    end

    def self.delete_material_from_library(library, materialname)
      json_path = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/resources/materials/#{library}.json"
      return unless File.exist?(json_path)

      json_data = begin
        JSON.parse(File.read(json_path))
      rescue StandardError
        []
      end
      json_data.reject! { |info| info["name"] == materialname }

      File.write(json_path, JSON.pretty_generate(json_data))
    end

    def self.duplicate_material_in_library(library_name, material_name)
      return if ["SketchUp materials in model"].include?(library_name)

      if library_name == "Skalp materials in model"
        su_material = Sketchup.active_model.materials[material_name]
        unless su_material && su_material.get_attribute("Skalp", "ID")
          UI.messagebox("Material '#{material_name}' not found or not a Skalp material.")
          return
        end

        # Request new name
        new_name = UI.inputbox(["New name for duplicate:"], ["#{material_name} (Copy)"], "Duplicate Material")
        return unless new_name && !new_name[0].strip.empty?

        new_name = new_name[0].strip

        if Sketchup.active_model.materials[new_name]
          UI.messagebox("A material with the name '#{new_name}' already exists in the model.")
          return
        end

        # Duplicate with attributes
        Skalp.active_model.start("Skalp - Duplicate Material", true)
        new_mat = Sketchup.active_model.materials.add(new_name)
        new_mat.color = su_material.color
        new_mat.alpha = su_material.alpha
        if su_material.texture
          new_mat.texture = su_material.texture.filename
          new_mat.texture.size = [su_material.texture.width, su_material.texture.height]
        end

        # Copy Skalp attributes
        if su_material.attribute_dictionaries["Skalp"]
          su_material.attribute_dictionaries["Skalp"].each_pair do |key, value|
            new_mat.set_attribute("Skalp", key, value)
          end
        end

        # Update pattern info with new name
        pattern_info = Skalp.get_pattern_info(new_mat)
        if pattern_info.is_a?(Hash)
          pattern_info[:name] = new_name
          new_mat.set_attribute("Skalp", "pattern_info", pattern_info.inspect)
        end

        Skalp.active_model.commit
        create_thumbnails(library_name)
        UI.messagebox("Material '#{new_name}' created.")
      else
        # Library (JSON) duplication
        json_path = File.join(Skalp::MATERIAL_PATH, "#{library_name}.json")
        return unless File.exist?(json_path)

        json_data = JSON.parse(File.read(json_path))
        original_info = json_data.find { |info| info["name"] == material_name }
        return unless original_info

        new_name = UI.inputbox(["New name for duplicate:"], ["#{material_name} (Copy)"], "Duplicate Material")
        return unless new_name && !new_name[0].strip.empty?

        new_name = new_name[0].strip

        if json_data.any? { |info| info["name"] == new_name }
          UI.messagebox("A material with the name '#{new_name}' already exists in '#{library_name}'.")
          return
        end

        new_info = original_info.dup
        new_info["name"] = new_name
        json_data << new_info
        File.write(json_path, JSON.pretty_generate(json_data))
        create_thumbnails(library_name)
        UI.messagebox("Material '#{new_name}' added to library '#{library_name}'.")
      end
    end
  end
end

# Add the ensure_png_blobs_for_model_materials method to the Skalp module (if not already present)
module Skalp
  def self.ensure_png_blobs_for_model_materials
    Sketchup.active_model.materials.each do |material|
      next unless material.get_attribute("Skalp", "ID")

      info_string = material.get_attribute("Skalp", "pattern_info")
      next unless info_string

      pattern_info = begin
        eval(info_string)
      rescue StandardError
        nil
      end
      next unless pattern_info.is_a?(Hash)

      next if pattern_info[:png_blob]

      png_blob = begin
        Skalp.create_thumbnail(pattern_info, 81, 27)
      rescue StandardError
        nil
      end
      if png_blob
        pattern_info[:png_blob] = png_blob
        material.set_attribute("Skalp", "pattern_info", pattern_info.inspect)
      end
    end
  end
end
