module Skalp
  class Section2D
    attr_accessor :polygons, :meshes, :section_material, :su_material, :num_polygons, :node, :outerloops, :innerloops

    def initialize(node)
      @model = Skalp.active_model
      @skpModel = @model.skpModel
      @node = node
      reset
    end

    def add_polygon(polygon)
      return if polygon.mesh.size < 3
      @meshes << polygon.mesh
      @poly_array = @poly_array + polygon.to_a
      @polygons << polygon
    end

    def add_polygons(polygons)
      reset
      polygons.polygons.each { |polygon| self.add_polygon(polygon) }
    end

    def meshes
      @meshes
    end

    def to_mpoly
      Skalp::MultiPolygon.new(@poly_array)
    end

    def to_a
      @poly_array
    end

    def each_line
      if block_given?
        @polygons.collect {|polygon| polygon.each_line { |x| yield(x) }}
      else
        return @polygons.collect {|polygon| polygon.each_line}
      end
    end

    def outline(lineweight)
      @outline_arrays[lineweight] || @outline_arrays[lineweight] = to_mpoly.outline(lineweight)
    end

    def inside(lineweight)
      @inside_arrays[lineweight] || @inside_arrays[lineweight] = to_mpoly.offset(-lineweight/2)
    end

    def reset
      @polygons = []
      @poly_array = []
      @outline_arrays = {}
      @inside_arrays = {}
      @meshes = []
    end

    def hatch_by_style(object)
      return 'Skalp default' unless object

      rules = Skalp.dialog.style_settings(object)[:style_rules]
      return 'Skalp default' unless rules

      # Cache frequently accessed properties
      node_value = @node.value
      su_material = node_value.su_material_used_by_hatch
      tags_array = nil # Lazy init only when needed
      
      rules.merge.reverse_each do |rule|
        case rule[:type]
        when :Scene
          page_name = rule[:type_setting]
          if page_name && @skpModel.pages[page_name] && !Skalp.scene_style_nested
            Skalp.scene_style_nested = true
            return hatch_by_style(@skpModel.pages[page_name])
          end

        when :ByLayer
          layer = @skpModel.layers[node_value.layer]
          if layer
            material = layer.get_attribute('Skalp', 'material')
            return material if material && !material.empty?
          end

        when :ByMultiTag
          material = node_value.multi_tags_hatch
          return material if material.is_a?(String) && !material.empty?

        when :ByTexture
          return su_material&.name || 'su_default' if su_material&.valid?

        when :Layer
          material = rule[:type_setting][node_value.layer_used_by_hatch]
          return material if material

        when :Tag
          if node_value.tag
            # Lazy initialize and cache tag splitting
            tags_array ||= node_value.tag.split(',').map { |tag| Skalp.utf8(tag.strip) }
            return rule[:pattern] if tags_array.include?(rule[:type_setting].strip)
          end

        when :Pattern
          return rule[:pattern] if rule[:type_setting] == @section_material

        when :Texture
          if su_material && su_material.valid?
            material = rule[:type_setting][su_material.name]
            return material if material
          end

        when :ByObject
          return @section_material if @section_material && @section_material != 'Skalp default'

        when :Model
          return rule[:pattern] || 'Skalp default'
        end
      end

      'Skalp default'
    end

    def layer_by_style(object, material)
      if @model.rendering_options.color_by_layer_active?(object)
        material = 'Skalp default' if material == '' || material == nil
        layername = "\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - ' + material.gsub(/%\d+\Z/, '')
        unless @skpModel.layers[layername]
          layername = "layer0"
        end

        return layername
      else
        return 'Layer0'
      end
    rescue
      return 'Layer0'
    end
  end
end
