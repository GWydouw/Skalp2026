module Skalp
  class Memory_attributes
    def initialize
      @model = Skalp.active_model
      @skpModel = @model.skpModel
      setup
    end

    attr_reader :model

    def [](object)
      @mem_attributes[object]
    end

    def attributes
      @mem_attributes
    end

    def []=(object, value)
      @mem_attributes[object] = value
    end

    def include?(object)
      @mem_attributes.include?(object)
    end

    def model=(model, save = false)
      save_to_model if save
      @model = model
      setup
    end

    def active_sectionplane_changed(page, mem_old)
      attrib_new = @mem_attributes[page]
      attrib_old = mem_old[page]

      return false if [nil, {}].include?(attrib_new) && [nil, {}].include?(attrib_old)
      return true if [nil, {}].include?(attrib_new) || [nil, {}].include?(attrib_old)

      attrib_new["sectionplaneID"] != attrib_old["sectionplaneID"]
    end

    def to_s
      if @mem_attributes[@skpModel]["selected_page"]
        "---- \n" +
          "scene:  #{@mem_attributes[@skpModel]['selected_page'].name}\n" +
          "timestamp: #{@mem_attributes[@skpModel]['page_undo']}\n" +
          "sectionplaneID: #{@mem_attributes[@skpModel]['active_sectionplane_ID']}\n" +
          "scale: #{@mem_attributes[@skpModel]['active_drawing_scale']}\n" +
          "style: #{@mem_attributes[@skpModel]['style']}\n" +
          "page changed: #{@mem_attributes[:page_changed]}\n" +
          "----"
      else
        "---- \n" +
          "scene: \n" +
          "timestamp: #{@mem_attributes[@skpModel]['page_undo']}\n" +
          "sectionplaneID: #{@mem_attributes[@skpModel]['active_sectionplane_ID']}\n" +
          "scale: #{@mem_attributes[@skpModel]['active_drawing_scale']}\n" +
          "style: #{@mem_attributes[@skpModel]['style']}\n" +
          "page changed: #{@mem_attributes[:page_changed]}\n" +
          "----"
      end
    end

    def read_status(status)
      @mem_attributes = status
      remove_unvalid_keys
    end

    def clear_save_memory_attributes_from_model
      attrdicts = @skpModel.attribute_dictionaries
      return unless attrdicts

      attrdict = attrdicts["Skalp_memory_attributes"]
      attrdict.each_key { |key| attrdict.delete_key(key) } if attrdict
    end

    def save_to_model
      remove_unvalid_keys

      @model.start("Skalp - #{Skalp.translate('save scene and model attributes from memory')}", false)
      clear_save_memory_attributes_from_model
      if !Skalp.active_model.skalp_version || (Skalp::SKALP_VERSION > Skalp.active_model.skalp_version)
        @model.set_memory_attribute(@skpModel, "Skalp", "skalp_version",
                                    Skalp::SKALP_VERSION)
      end

      @mem_attributes.each_pair do |object, hash_value|
        next unless object.valid?

        case object
        when Sketchup::Model
          hash_value.each_pair do |key, value|
            process_attributes_for_write("skpModel|", key, value)
          end
        when Sketchup::Page
          object.set_attribute("Skalp", "ID", hash_value["ID"].to_s)
          hash_value.each_pair do |key, value|
            process_attributes_for_write("#{hash_value['ID']}|", key, value)
          end
        end
      end
      Skalp.insert_version_check_code
      @model.commit
    end

    def process_attributes_for_write(index_name, key_name, value)
      if key_name == "style_settings" && value.class == Hash
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "drawing_scale", value[:drawing_scale].to_s)
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "rearview_status", value[:rearview_status].to_s)
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "rearview_linestyle",
                                value[:rearview_linestyle].to_s)
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "lineweights_status",
                                value[:section_cut_width_status].to_s)
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "fog_status",
                                value[:depth_clipping_status].to_s)
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "fog_distance",
                                value[:depth_clipping_distance].to_s)
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + "style_rules",
                                value[:style_rules].rules.inspect)
      else
        @skpModel.set_attribute("Skalp_memory_attributes", index_name + key_name.to_s, value.to_s)
      end
    end

    def default_settings
      style_rules = StyleRules.new
      style_rules.setup_default

      distance = Distance.new("300cm")

      {
        drawing_scale: Skalp.default_drawing_scale,
        rearview_status: false,
        section_cut_width_status: false,
        depth_clipping_status: false,
        depth_clipping_distance: distance,
        style_rules: style_rules
      }
    end

    def read_from_model
      puts "\n=== SKALP: Start Reading Memory Attributes (MIGRATION CHECK) ==="
      saved_memory_attributes = @skpModel.attribute_dictionary("Skalp_memory_attributes")

      to_check = []
      if saved_memory_attributes
        puts "[LOG] Found 'Skalp_memory_attributes' dictionary with #{saved_memory_attributes.count} entries."
        saved_memory_attributes.each_pair do |key, value|
          key_array = key.split("|")
          object = key_array[0]
          key_name = key_array[1]

          case object
          when "skpModel"
            puts "[LOG] Validating Model attribute: #{key_name} = #{value}"
            to_check << @skpModel
            process_attributes_for_read(@mem_attributes[@skpModel], key_name, value)
          else
            skpPage = find_page(object)

            if skpPage && @mem_attributes[skpPage]
              puts "[LOG] Validating Page attribute for '#{skpPage.name}': #{key_name} = #{value}"
              to_check << skpPage
              process_attributes_for_read(@mem_attributes[skpPage], key_name, value)
            else
              puts "[LOG] WARNING: Could not find page for ID '#{object}' (Key: #{key}). Skipping."
            end
          end
        end

        check_attributes(to_check)
      else
        puts "[LOG] No 'Skalp_memory_attributes' dictionary found. initializing defaults."
        @mem_attributes[Sketchup.active_model] = {}
        @mem_attributes[Sketchup.active_model]["style_settings"] = default_settings
        save_to_model
      end

      # MIGRATION SU2026: Sync migrated data to native page attributes
      puts "\n=== SKALP: Syncing to Native Attributes ==="
      sync_to_native_attributes

      puts "\n=== SKALP: Final Active Memory Attributes State ==="
      log_current_state

      puts "\n=== SKALP: VERIFICATION - Native Attributes State ==="
      log_native_attributes_state
    end

    # MIGRATION SU2026: Write @mem_attributes to native page attributes
    # This ensures old format data is migrated to new native format
    def sync_to_native_attributes
      @mem_attributes.each_pair do |object, attrs|
        begin
          next unless object && object.valid?
        rescue StandardError
          next
        end
        next unless attrs.is_a?(Hash)

        object_name = object.is_a?(Sketchup::Model) ? "Model" : "Page '#{object.name}'"

        attrs.each_pair do |key, value|
          next if key == "commit"

          if key == "style_settings" && value.is_a?(Hash)
            # Flatten style settings to native attributes (ss_*)
            # Must match keys in Skalp_model.rb
            style_keys = %i[drawing_scale rearview_status rearview_linestyle section_cut_width_status
                            depth_clipping_status depth_clipping_distance style_rules]

            value.each do |style_key, style_value|
              # Only migrate known valid style keys
              next unless style_keys.include?(style_key) || style_keys.include?(style_key.to_sym)

              begin
                if [:style_rules, "style_rules"].include?(style_key) && style_value.respond_to?(:rules)
                  object.set_attribute("Skalp", "ss_#{style_key}", style_value.rules.inspect)
                elsif !style_value.is_a?(Hash)
                  # HEURISTIC FIX: If page has rearview_status false but model has it true, force it to true
                  # This fixes models where rearview was globally enabled but stagnant page values stayed false.
                  if style_key == :rearview_status && ["false", false].include?(style_value)
                    # Try to find Model's rearview setting in current memory attributes
                    model_attrs = @mem_attributes[Sketchup.active_model]
                    model_rv = model_attrs["rearview_status"] if model_attrs

                    if ["true", true].include?(model_rv)
                      style_value = true
                      puts "[LOG] Healing #{object_name}: rearview_status forced to TRUE to match Model"
                    end
                  end

                  object.set_attribute("Skalp", "ss_#{style_key}", style_value.to_s)
                end
              rescue StandardError => e
                puts "[ERROR] Failed to transfer #{object_name} style setting '#{style_key}': #{e.message}"
              end
            end
            next
          end

          next if value.is_a?(Hash) # Skip other complex hashes

          begin
            object.set_attribute("Skalp", key, value) if value
          rescue StandardError => e
            puts "[ERROR] Failed to transfer #{object_name}: '#{key}' -> '#{value}': #{e.message}"
          end
        end
      end
    end

    def log_current_state
      @mem_attributes.each_pair do |object, attrs|
        begin
          next unless object && object.valid?
        rescue StandardError
          next
        end
        object_name = object.is_a?(Sketchup::Model) ? "Model" : "Page '#{object.name}'"
        puts "--- #{object_name} ---"
        if attrs.is_a?(Hash)
          attrs.each do |k, v|
            if k == "style_settings" && v.is_a?(Hash)
              puts "  #{k}:"
              v.each { |sk, sv| puts "    #{sk}: #{sv}" }
            else
              puts "  #{k}: #{v}"
            end
          end
        else
          puts "  #{attrs.inspect}"
        end
      end
      puts "=================================================\n"
    end

    def log_native_attributes_state
    end

    def check_attributes(objects)
      objects.each do |object|
        object_attributes = @mem_attributes[object]
        style_settings = object_attributes["style_settings"]
        next unless style_settings.class == Hash

        object_attributes["style_settings"] = if object.class == Sketchup::Model || style_settings[:style_rules]
                                                default_settings.merge(style_settings)
                                              else
                                                nil
                                              end
      end
    end

    def process_attributes_for_read(object_attributes, key_name, value)
      object_attributes["style_settings"] = {} unless object_attributes["style_settings"]
      style_settings = object_attributes["style_settings"]

      case key_name
      when "save_settings_status"
      # do nothing
      when "active_drawing_scale", "drawing_scale"
        style_settings[:drawing_scale] = value.to_f if value.to_f != 0.0
      when "rearview_status"
        style_settings[:rearview_status] = Skalp.to_boolean(value)
      when "lineweights_status"
        style_settings[:section_cut_width_status] = Skalp.to_boolean(value)
      when "rearview_linestyle"
        value = "Dash" if [nil, ""].include?(value)
        style_settings[:rearview_linestyle] = value
      when "fog_status"
        style_settings[:depth_clipping_status] = Skalp.to_boolean(value)
      when "fog_distance"
        style_settings[:depth_clipping_distance] = Distance.new(value)
      when "style_rules"
        begin
          style_settings[:style_rules] = value ? StyleRules.new(eval(value)) : StyleRules.new
        rescue StandardError => e
          puts "Skalp Debug: Error evaluating style_rules in memory_attributes: #{e.message}"
          puts e.backtrace.first(3).join("\n")
          style_settings[:style_rules] = StyleRules.new
        end
      when "style"
        style_rules = StyleRules.new
        value.class == Array ? style_rules.load_from_attribute_style(value) : style_rules.setup_default
        style_settings[:style_rules] = style_rules
      when "style_hatch", "style_layer"
      # do nothing
      else
        object_attributes[key_name] = value
      end
    end

    def find_page(id)
      @skpModel.pages.each do |page|
        return page if page.get_attribute("Skalp", "ID") == id
      end

      rescue_find_page(id)
    end

    def rescue_find_page(id)
      layer = @model.layer_by_id(id)
      return nil unless layer

      scene_layer = layer.skpLayer
      return nil unless scene_layer

      scene_layers = find_all_scene_layers
      layers = @skpModel.layers.to_a

      found_pages = []
      @skpModel.pages.each do |page|
        active_layers = layers - page.layers.to_a
        other_scene_layers = scene_layers - [scene_layer]

        if ((active_layers - other_scene_layers).size == active_layers.size) && active_layers.include?(scene_layer)
          found_pages << page
        end
      end

      if found_pages.size == 1
        return found_pages.first
      elsif found_pages
        found_pages.each do |page|
          return page if page.name == scene_layer.name[8..-1]
        end
      end

      nil
    end

    def find_all_scene_layers
      scene_layers = []
      @skpModel.layers.each do |layer|
        scene_layers << layer if layer.get_attribute("Skalp", "ID") && layer.name.include?("Scene:")
      end
      scene_layers
    end

    def dup
      remove_unvalid_keys
      dup_object = Memory_attributes.new
      @mem_attributes.each_pair { |key, value| dup_object[key] = dup_attributes(value) }

      dup_object
    end

    private

    def setup(status = nil)
      @mem_attributes = {}
      @mem_attributes[@model.skpModel] = {}
      return unless @model.skpModel.pages

      @model.skpModel.pages.each do |page|
        @mem_attributes[page] = {}
      end
    end

    def read_attributes(object)
      return unless object.attribute_dictionaries
      return unless object.attribute_dictionaries["Skalp"]

      page_attributes = @mem_attributes[object]
      object.attribute_dictionaries["Skalp"].each_pair do |key, value|
        page_attributes[key] = value unless key == "commit"
      end
    end

    def save_attributes(object)
      page_attributes = @mem_attributes[object]

      page_attributes.each_pair do |key, value|
        object.set_attribute("Skalp", key, value)
      end
    end

    def dup_attributes(value)
      dup_value = {}

      value.each_pair do |key, value|
        dup_value[key] = if [Hash, Array].include?(value.class)
                           Marshal.load(Marshal.dump(value))
                         else
                           value
                         end
      end

      dup_value
    end

    def remove_unvalid_keys
      objects = []
      objects << @model.skpModel if @model && @model.skpModel

      if @model && @model.skpModel && @model.skpModel.pages
        @model.skpModel.pages.each do |page|
          objects << page if page.class == Sketchup::Page
        end
      end

      to_delete = []
      @mem_attributes.each_key { |key| to_delete << key unless objects.include?(key) }
      to_delete.each do |key|
        @mem_attributes.delete(key)
      end
    end
  end
end
