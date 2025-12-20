module Skalp
  class StyleRules
    include Enumerable
    attr_reader :rules

    TYPES = [:Model, :ByLayer, :ByMultiTag, :ByObject, :ByTexture, :Layer, :Texture, :Tag, :Pattern, :Scene]

    # TODO dump and load marshal (for undo)

    def initialize(style_rules = nil)
      style_rules ? check(style_rules) : @rules = []
    end

    def marshal_dump
      @rules
    end

    def marshal_load array
      @rules = array
    end

    def setup_default
      create_default_model_rule
    end

    def add_rule(*args)
      type = args[0]

      return if !@rules.empty? && type == :Model
      create_default_model_rule if @rules.empty? && type != :Model
      return unless TYPES.include?(type)

      @rules << create_rule(args)
    end

    def each(&block)
      read_rules = @rules.reverse
      read_rules.each(&block)
    end

    def load_from_attribute_style(style)
      @rules = []
      style = convert_v1_style(style) if style[2].gsub(':', '').to_sym == :model_layer
      style.each { |rule| add_rule(rule) }
    end

    def to_dialog
      return unless Skalp.dialog
      return unless @rules

      style_update_status = Skalp.style_update
      Skalp.style_update = false

      Skalp.dialog.script("$('#sortable').empty();")
      Skalp.dialog.script("add_row(#{@rules.size - 1});")

      row = 0
      @rules.each do |rule|
        if rule[:type] == :Model
          add_model_pattern_to_dialog(rule)
        else
          row += 1
          add_rule_to_dialog(rule, row)
        end
      end

      Skalp.style_update = style_update_status
    end

    def from_dialog(params)
      return if params.class != Array

      add_rule(:Model, Skalp.utf8(params[1]))
      style_rules = params[2..-1]

      for i in (0..style_rules.size - 1).step(14)
        style_type = style_rules[i + 2]
        style_type_setting = Skalp.utf8(style_rules[i + 5])
        style_pattern = Skalp.utf8(style_rules[i + 11])

        next if style_type == '' || style_type == 'undefined'

        case style_type
        when ':Scene'
          next if style_type_setting == '' || style_type_setting == 'undefined'
          add_rule(:Scene, style_type_setting)

        when ':Layer'
          next if style_type_setting == '' || style_type_setting == 'undefined' || style_pattern == '' || style_pattern == 'undefined'
          add_rule(:Layer, style_type_setting, style_pattern)

        when ':Pattern'
          next if style_type_setting == '' || style_type_setting == 'undefined' || style_pattern == '' || style_pattern == 'undefined'
          add_rule(:Pattern, style_type_setting, style_pattern)

        when ':Tag'
          next if style_type_setting == '' || style_type_setting == 'undefined' || style_pattern == '' || style_pattern == 'undefined'
          add_rule(:Tag, style_type_setting, style_pattern)

        when ':Texture'
          next if style_type_setting == '' || style_type_setting == 'undefined' || style_pattern == '' || style_pattern == 'undefined'
          add_rule(:Texture, style_type_setting, style_pattern)

        when ':ByObject', ':object'
          next if style_type_setting == '' || style_type_setting == 'undefined'
          add_rule(:ByObject, style_type_setting, style_pattern)

        when ':ByLayer'
          next if style_type_setting == '' || style_type_setting == 'undefined'
          add_rule(:ByLayer, style_type_setting, style_pattern)

        when ':ByMultiTag'
          next if style_type_setting == '' || style_type_setting == 'undefined'
          add_rule(:ByMultiTag, style_type_setting, style_pattern)

        when ':ByTexture'
          next if style_type_setting == '' || style_type_setting == 'undefined'
          add_rule(:ByTexture, style_type_setting, style_pattern)
        end
      end
    end

    def save_to_library
      path = UI.savepanel("#{Skalp.translate('Save Skalp Style as...')}", Dir.home, "#{Skalp.translate('Style01')}.skalp")
      return unless path

      unless path[-6..-1] == '.skalp'
        path = path + '.skalp'
      end

      File.open(path, 'w') do |file|
        file.puts "styles_version_02"
        file.puts @rules.inspect
      end
    end

    def load_from_library
      chosen_skalp_style = UI.openpanel("Load Skalp Style", Dir.home, "Skalp Styles|*.skalp||")
      return unless chosen_skalp_style

      if chosen_skalp_style[-6..-1] == '.skalp'
        style_file = []
        file = File.open(chosen_skalp_style, 'r')
        file.each_line { |line| style_file << line.gsub(/\n/, "") }
        file.close

        version = style_file[0]

        if version == 'styles_version_01'
          old_style = eval(style_file[1])
          if old_style.class == Array
            load_from_attribute_style(old_style)
          else
            UI.messagebox('Error reading Style file! 1')
            return
          end
        elsif version == 'styles_version_02'
          @rules = eval(style_file[1])
        else
          UI.messagebox('Error reading Style file!')
          return
        end

        to_dialog
      end
    end

    def merge
      merged_rules = []

      layer_merge_started = false
      texture_merge_started = false

      layers = nil
      textures = nil

      @rules.each do |rule|

        if rule[:type] == :Layer
          if layer_merge_started == false
            layers = {}
            layer_merge_started = true
          end
          layers[rule[:type_setting]] = rule[:pattern]
        elsif rule[:type] == :Texture
          if texture_merge_started == false
            textures = {}
            texture_merge_started = true
          end
          textures[rule[:type_setting]] = rule[:pattern]
        else
          if layers && layers != {}
            merged_rules << { type: :Layer, type_setting: layers }
            layer_merge_started = false
          elsif textures && textures != {}
            merged_rules << { type: :Texture, type_setting: textures }
            texture_merge_started = false
          end
          merged_rules << rule
        end
      end

      merged_rules << { type: :Layer, type_setting: layers } if layer_merge_started
      merged_rules << { type: :Texture, type_setting: textures } if texture_merge_started

      merged_rules
    end

    def create_default_model_rule
      @rules = [create_rule([:Model, 'Skalp default']), create_rule([:ByLayer, 'by Tag']), create_rule([:ByObject, 'by Object'])]
    end

    private

    def check(style_rules)
      if style_rules.class == Array
        @rules = style_rules
      else
        create_default_model_rule
      end
    end

    def add_model_pattern_to_dialog(rule)
      Skalp.dialog.script("$('#model_material').val('#{rule[:pattern]}');")
      Skalp.dialog.script("highlight($('#model_material'), true)")
    end

    def add_rule_to_dialog(rule, row)
      rule[:type_setting] = 'by Tag' if rule[:type] == :ByLayer # renaming layer to tag in SU2020

      Skalp.dialog.script("$('#sortable tr:nth-child(#{row}) .selector_type').val('#{rule[:type].inspect}').change();")
      Skalp.dialog.script("$('#sortable tr:nth-child(#{row}) .selector_name_value').val('#{rule[:type_setting]}');")
      Skalp.dialog.script("$('#sortable tr:nth-child(#{row}) .convert_to_value').val('#{rule[:pattern]}');")
      Skalp.dialog.script("save_style()")

      case rule[:type]
      when :ByLayer
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), false)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), false)")
      when :ByMultiTag
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), false)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), false)")
      when :ByTexture
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), false)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), false)")
      when :ByObject
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), false)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), false)")
      when :Scene
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), true)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), false)")
      when :Texture
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), true)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), true)")
      when :Pattern
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), true)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), true)")
      when :Tag
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), true)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), true)")
      when :Layer
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .selector_name_value'), true)")
        Skalp.dialog.script("highlight($('#sortable tr:nth-child(#{row}) .convert_to_value'), true)")
      end
    end

    def convert_v1_style(old_style)
      # OLD style: [":model_material", "wit", ":model_layer", "Skalp Pattern Layer", ":matByLayer", "by Layer", ":2hatch", ""]
      # NEW_style: [{type: :Model, pattern: 'Skalp default'}]
      # NEW_style: [{type: :Layer, type_setting: 'Layer0', pattern: 'Skalp default'}]
      # NEW_style: [{type: :ByLayer}]
      # NEW_style: [{type: :Scene, type_setting: 'Scene0'}]

      for n in (0..old_style.size - 1).step(4)
        old_type = old_style[n]
        old_type_setting = old_style[n + 1]
        old_pattern = old_style[n + 3]

        case old_type.gsub(':', '').to_sym
        when :model_material
          add_rule(:Model, old_style[n + 1])

        when :scene
          add_rule(:Scene, old_type_setting)

        when :layer
          add_rule(:Layer, old_type_setting, old_pattern)

        when :pattern
          add_rule(:Pattern, old_type_setting, old_pattern)

        when :tag
          add_rule(:Tag, old_type_setting, old_pattern)

        when :material
          add_rule(:Texture, old_type_setting, old_pattern)

        when :matByObject, :object
          add_rule(:ByObject, 'by Object')

        when :matByLayer
          add_rule(:ByLayer, 'by Tag')

        when :matByMuliTag
          add_rule(:ByMultiTag, 'by MultiTag')

        when :matByTexture
          add_rule(:ByTexture, 'by Texture')
        end
      end
    end

    def create_rule(args)
      type = args[0]
      type_setting = nil
      pattern = nil

      case type
      when :Model
        pattern = args[1]
      when :ByLayer
        type_setting = args[1]
      when :ByMultiTag
        type_setting = args[1]
      when :ByObject
        type_setting = args[1]
      when :ByTexture
        type_setting = args[1]
      when :Layer
        type_setting = args[1]
        pattern = args[2]
      when :Texture
        type_setting = args[1]
        pattern = args[2]
      when :Tag
        type_setting = args[1]
        pattern = args[2]
      when :Pattern
        type_setting = args[1]
        pattern = args[2]
      when :Scene
        type_setting = args[1]
      end

      { type: type, type_setting: type_setting, pattern: pattern }
    end

  end
end
