module Skalp

  class DXF_export
    # http://www.autodesk.com/techpubs/autocad/acadr14/dxf/
    # https://www.autodesk.com/techpubs/autocad/acad2000/dxf/index.htm   (needed for lineweights)

    attr_accessor :dxf_file

    def initialize(filename, scenename, hatched_polygons, forward_lines_by_layer, reversed_lines_by_layer, min, max, scale,
                   reversed_linetype='DASHED')

      scale = 1.0 if scale == Float::INFINITY
      @hatch_suffix = Skalp.layer_preset[:hatch_suffix]
      @fill_suffix = Skalp.layer_preset[:fill_suffix]
      @forward_layer = Skalp.layer_preset[:forward_layer]
      @forward_suffix = Skalp.layer_preset[:forward_suffix]
      @forward_color = Skalp.layer_preset[:forward_color]
      @rear_layer = Skalp.layer_preset[:rear_layer]
      @rear_suffix = Skalp.layer_preset[:rear_suffix]
      @rear_color = Skalp.layer_preset[:rear_color]
      @export_path = Sketchup.active_model.path.gsub(File.basename(Sketchup.active_model.path), "")

      @min = min
      @max = max

      @reversed_linetype = reversed_linetype.gsub(' ','_').upcase
      @reversed_linetype = 'CONTINUOUS' if @reversed_linetype == 'SOLID_BASIC'

      if Skalp::dialog.dxf_path
        if scenename == ''
          filepath = Skalp::dialog.dxf_path + filename + ".dxf"
        else
          filepath = Skalp::dialog.dxf_path + filename + "-#{scenename}.dxf"
        end

        @dxf = File.open(filepath, "wb")
        hatched_polygons ? @hatched_polygons = hatched_polygons : @hatched_polygons = []

        forward_lines_by_layer ? @forward_lines_by_layer = forward_lines_by_layer : @forward_lines_by_layer = {}
        reversed_lines_by_layer ? @reversed_lines_by_layer = reversed_lines_by_layer : @reversed_lines_by_layer = {}

        @scale = scale * Skalp::inch_to_modelunits(1)
        @handle = 100
        header
        @dxf.close
      else
        UI.messagebox(Skalp.translate('Your model needs to be saved first.'))
      end

    rescue StandardError => e
      pp e.message
      pp e.backtrace.inspect
      UI.messagebox("#{Skalp.translate('Permission denied')} - #{filepath}")
    end

    class Hatch
      attr_accessor :name, :angle, :scale, :hatchlines

      def initialize(name, angle, scale, hatchdef, hatch_polygon)
        @hatch_polygon = hatch_polygon
        @name = name
        @angle = angle
        @scale = scale * Skalp::inch_to_modelunits(1) * @hatch_polygon.section_scale
        @hatchlines = hatchdef.hatchlines
      end
    end

    class Hatched_polygon
      attr_accessor :outerloop, :innerloops, :hatch, :fillcolor, :has_fill, :has_hatch
      attr_reader :section_scale, :layer, :angle, :lineweight, :hatch_lineweight, :linecolor

      def initialize(outerloop, innerloops, su_pattern, section_scale, layer)
        layer ? @layer = Skalp.layer_check(layer) : @layer = 'Layer0'

        @section_scale = section_scale #drawing scale example 0.02 (1/50)
        @outerloop = outerloop
        @innerloops = innerloops
        @has_fill = false
        @has_hatch = false
        @longest_edge = nil

        su_material = Sketchup.active_model.materials[su_pattern] if su_pattern

        if Skalp.aligned(su_material)
          @longest_edge = outerloop.longest_edge
          if @longest_edge
            @angle = @longest_edge.angle
          else
            @angle = 0
          end
        else
          @angle = 0
        end

        if su_material
          if su_material.get_attribute('Skalp', 'ID')
            pattern_info = Skalp.get_pattern_info(su_material)
            rgb_fill = pattern_info[:fill_color].scan(/\d{1,3}/)
            rgb_line = pattern_info[:line_color].scan(/\d{1,3}/)

            if rgb_fill == nil || rgb_line == nil
              @has_fill = false
              @has_hatch = false
              return
            end

            if rgb_fill == ['255', '255', '255']
              @has_fill = false
            else
              @fillcolor = rgb2truecolor(rgb_fill[0].to_i, rgb_fill[1].to_i, rgb_fill[2].to_i)
              #TODO transparantie code 440
              @has_fill = true
            end

            @lineweight = Skalp::inch2dxf_lineweight(pattern_info[:section_cut_width])

            if rgb_line == ['0', '0', '0']
              @linecolor = 7
            else
              @linecolor = rgb2truecolor(rgb_line[0].to_i, rgb_line[1].to_i, rgb_line[2].to_i)
            end

            @hatch_lineweight = Skalp::inch2dxf_lineweight(Skalp::pen2inch(pattern_info[:pen]))

            if pattern_info[:name] && pattern_info[:pat_scale] && pattern_info[:pattern] && rgb_line != rgb_fill
              hatchdef = SkalpHatch::HatchDefinition.new(pattern_info[:pattern], false)

              @hatch = Hatch.new(pattern_info[:name], 0, pattern_info[:pat_scale], hatchdef, self)

              if @longest_edge
                hatchdef.rotate!(@angle)
                hatchdef.scale!(@hatch.scale)
                hatchdef.translate!(@longest_edge.startpoint.x * Skalp::inch_to_modelunits(1), @longest_edge.startpoint.y * Skalp::inch_to_modelunits(1))
              else
                hatchdef.scale!(@hatch.scale)
              end

              @has_hatch = true if @hatch
            else
              @hatch = false
            end

          else
            su_material.texture ? rgb = su_material.texture.average_color.to_a : rgb = su_material.color.to_a

            if rgb == ['255', '255', '255']
              @has_fill = false
              @has_hatch = false
            else
              @fillcolor = rgb2truecolor(rgb[0].to_i, rgb[1].to_i, rgb[2].to_i)
              @has_fill = true
              @has_hatch =false
            end
          end
        else
          @has_fill = false
          @has_hatch = false
        end
      end

      def rgb2truecolor(r,g,b)
        #http://www.rapidtables.com/web/color/RGB_Color.htm
        (r*65536)+(g*256)+b
      end
    end

    def rgb2truecolor(r,g,b)
      #http://www.rapidtables.com/web/color/RGB_Color.htm
      (r*65536)+(g*256)+b
    end

    def rgb2aci_color(r, g, b)
      return 7 if r == 255 && g == 255 && b == 255

      #AutoCAD Color Index (ACI) RGB equivalents http://sub-atomic.com/~moses/acadcolors.html
      aci_colors = [
          [0, 0, 0],
          [255, 0, 0],
          [255, 255, 0],
          [0, 255, 0],
          [0, 255, 255],
          [0, 0, 255],
          [255, 0, 255],
          [2550, 2550, 2550],
          [65, 65, 65],
          [128, 128, 128],
          [255, 0, 0],
          [255, 170, 170],
          [189, 0, 0],
          [189, 126, 126],
          [129, 0, 0],
          [129, 86, 86],
          [104, 0, 0],
          [104, 69, 69],
          [79, 0, 0],
          [79, 53, 53],
          [255, 63, 0],
          [255, 191, 170],
          [189, 46, 0],
          [189, 141, 126],
          [129, 31, 0],
          [129, 96, 86],
          [104, 25, 0],
          [104, 78, 69],
          [79, 19, 0],
          [79, 59, 53],
          [255, 127, 0],
          [255, 212, 170],
          [189, 94, 0],
          [189, 157, 126],
          [129, 64, 0],
          [129, 107, 86],
          [104, 52, 0],
          [104, 86, 69],
          [79, 39, 0],
          [79, 66, 53],
          [255, 191, 0],
          [255, 234, 170],
          [189, 141, 0],
          [189, 173, 126],
          [129, 96, 0],
          [129, 118, 86],
          [104, 78, 0],
          [104, 95, 69],
          [79, 59, 0],
          [79, 73, 53],
          [255, 255, 0],
          [255, 255, 170],
          [189, 189, 0],
          [189, 189, 126],
          [129, 129, 0],
          [129, 129, 86],
          [104, 104, 0],
          [104, 104, 69],
          [79, 79, 0],
          [79, 79, 53],
          [191, 255, 0],
          [234, 255, 170],
          [141, 189, 0],
          [173, 189, 126],
          [96, 129, 0],
          [118, 129, 86],
          [78, 104, 0],
          [95, 104, 69],
          [59, 79, 0],
          [73, 79, 53],
          [127, 255, 0],
          [212, 255, 170],
          [94, 189, 0],
          [157, 189, 126],
          [64, 129, 0],
          [107, 129, 86],
          [52, 104, 0],
          [86, 104, 69],
          [39, 79, 0],
          [66, 79, 53],
          [63, 255, 0],
          [191, 255, 170],
          [46, 189, 0],
          [141, 189, 126],
          [31, 129, 0],
          [96, 129, 86],
          [25, 104, 0],
          [78, 104, 69],
          [19, 79, 0],
          [59, 79, 53],
          [0, 255, 0],
          [170, 255, 170],
          [0, 189, 0],
          [126, 189, 126],
          [0, 129, 0],
          [86, 129, 86],
          [0, 104, 0],
          [69, 104, 69],
          [0, 79, 0],
          [53, 79, 53],
          [0, 255, 63],
          [170, 255, 191],
          [0, 189, 46],
          [126, 189, 141],
          [0, 129, 31],
          [86, 129, 96],
          [0, 104, 25],
          [69, 104, 78],
          [0, 79, 19],
          [53, 79, 59],
          [0, 255, 127],
          [170, 255, 212],
          [0, 189, 94],
          [126, 189, 157],
          [0, 129, 64],
          [86, 129, 107],
          [0, 104, 52],
          [69, 104, 86],
          [0, 79, 39],
          [53, 79, 66],
          [0, 255, 191],
          [170, 255, 234],
          [0, 189, 141],
          [126, 189, 173],
          [0, 129, 96],
          [86, 129, 118],
          [0, 104, 78],
          [69, 104, 95],
          [0, 79, 59],
          [53, 79, 73],
          [0, 255, 255],
          [170, 255, 255],
          [0, 189, 189],
          [126, 189, 189],
          [0, 129, 129],
          [86, 129, 129],
          [0, 104, 104],
          [69, 104, 104],
          [0, 79, 79],
          [53, 79, 79],
          [0, 191, 255],
          [170, 234, 255],
          [0, 141, 189],
          [126, 173, 189],
          [0, 96, 129],
          [86, 118, 129],
          [0, 78, 104],
          [69, 95, 104],
          [0, 59, 79],
          [53, 73, 79],
          [0, 127, 255],
          [170, 212, 255],
          [0, 94, 189],
          [126, 157, 189],
          [0, 64, 129],
          [86, 107, 129],
          [0, 52, 104],
          [69, 86, 104],
          [0, 39, 79],
          [53, 66, 79],
          [0, 63, 255],
          [170, 191, 255],
          [0, 46, 189],
          [126, 141, 189],
          [0, 31, 129],
          [86, 96, 129],
          [0, 25, 104],
          [69, 78, 104],
          [0, 19, 79],
          [53, 59, 79],
          [0, 0, 255],
          [170, 170, 255],
          [0, 0, 189],
          [126, 126, 189],
          [0, 0, 129],
          [86, 86, 129],
          [0, 0, 104],
          [69, 69, 104],
          [0, 0, 79],
          [53, 53, 79],
          [63, 0, 255],
          [191, 170, 255],
          [46, 0, 189],
          [141, 126, 189],
          [31, 0, 129],
          [96, 86, 129],
          [25, 0, 104],
          [78, 69, 104],
          [19, 0, 79],
          [59, 53, 79],
          [127, 0, 255],
          [212, 170, 255],
          [94, 0, 189],
          [157, 126, 189],
          [64, 0, 129],
          [107, 86, 129],
          [52, 0, 104],
          [86, 69, 104],
          [39, 0, 79],
          [66, 53, 79],
          [191, 0, 255],
          [234, 170, 255],
          [141, 0, 189],
          [173, 126, 189],
          [96, 0, 129],
          [118, 86, 129],
          [78, 0, 104],
          [95, 69, 104],
          [59, 0, 79],
          [73, 53, 79],
          [255, 0, 255],
          [255, 170, 255],
          [189, 0, 189],
          [189, 126, 189],
          [129, 0, 129],
          [129, 86, 129],
          [104, 0, 104],
          [104, 69, 104],
          [79, 0, 79],
          [79, 53, 79],
          [255, 0, 191],
          [255, 170, 234],
          [189, 0, 141],
          [189, 126, 173],
          [129, 0, 96],
          [129, 86, 118],
          [104, 0, 78],
          [104, 69, 95],
          [79, 0, 59],
          [79, 53, 73],
          [255, 0, 127],
          [255, 170, 212],
          [189, 0, 94],
          [189, 126, 157],
          [129, 0, 64],
          [129, 86, 107],
          [104, 0, 52],
          [104, 69, 86],
          [79, 0, 39],
          [79, 53, 66],
          [255, 0, 63],
          [255, 170, 191],
          [189, 0, 46],
          [189, 126, 141],
          [129, 0, 31],
          [129, 86, 96],
          [104, 0, 25],
          [104, 69, 78],
          [79, 0, 19],
          [79, 53, 59],
          [51, 51, 51],
          [80, 80, 80],
          [105, 105, 105],
          [130, 130, 130],
          [190, 190, 190],
          [255, 255, 255]]

      closest_color_dist = nil
      closest_color_index = nil
      for color in aci_colors
        dist = (r-color[0])*(r-color[0]) + (g-color[1])*(g-color[1]) + (b-color[2])*(b-color[2])
        if closest_color_dist
          if dist < closest_color_dist
            closest_color_dist = dist
            closest_color_index = aci_colors.index(color)
          end
        else
          closest_color_dist = dist
          closest_color_index = aci_colors.index(color)
        end
      end

      return closest_color_index
    end

    def next_handle
      @handle += 1
      sprintf "%x", @handle
    end

    def group(code, value)
      @dxf.printf "%3i\r\n%s\r\n", code, value.to_s
    end

    def header
      group(999, 'Skalp for SketchUp')
      group(0, 'SECTION')
      group(2, 'HEADER')
      group(9, '$ACADVER')
      group(1, 'AC1018')
      group(9, '$DWGCODEPAGE')
      group(3, 'ANSI_1252')
      group(9, '$REGENMODE')
      group(70, 1)
      group(9, '$LUNITS')
      group(70, sketchup_length_unit)
      group(9, '$INSUNITS')
      group(70, sketchup_unit)
      group(9, '$LUPREC')
      group(70, sketchup_length_unit_precision)
      group(9, '$AUNITS')
      group(70, sketchup_angle_unit)
      group(9, '$AUPREC')
      group(70, sketchup_angle_unit_precision)
      group(9, '$LWDISPLAY')
      group(290, 1)
      group(9, '$LTSCALE')
      group(40, 1.0)
      group(9, '$PSLTSCALE')
      group(70, 1.0)
      group(9, '$MEASUREMENT')
      group(70, sketchup_measurement) #Sets drawing units: 0 = English; 1 = Metric
      group(9, '$HANDSEED') #Next available handle
      group(5, 'FFFFF')
      group(0, 'ENDSEC')
      classes
      tables
      blocks
      entities
      objects
      group(0, 'EOF')
    end

    # dxf length units
    # 2 = decimal
    # 3 = engineering
    # 4 = architectural
    # 5 = fractional

    # SketchUp lengthFormat
    # 0 = decimal  lengthUnit 0=inch, 1=feet, 2=mm, 3=cm, 4=m
    # 1 = architectural  lengthUnit = 0
    # 2 = engineering
    # 3 = fractional
    #
    #
    # Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
    # returns an integer - this corresponds to the units as follows:
    # 0 = "
    # 1 = '
    # 2 = mm
    # 3 = cm
    # 4 = m
    #
    #
    #
    # Default drawing units for AutoCAD DesignCenter blocks:
    #                                                    0 = Unitless; 1 = Inches; 2 = Feet; 3 = Miles; 4 = Millimeters;
    # 5 = Centimeters; 6 = Meters; 7 = Kilometers; 8 = Microinches;
    # 9 = Mils; 10 = Yards; 11 = Angstroms; 12 = Nanometers;
    # 13 = Microns; 14 = Decimeters; 15 = Decameters;
    # 16 = Hectometers; 17 = Gigameters; 18 = Astronomical units;
    # 19 = Light years; 20 = Parsecs

    def sketchup_unit
      case Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]
      when 0 #inch
        return 1
      when 1 #feet
        return 2
      when 2 #mm
        return 4
      when 3 #cm
        return 5
      when 4 #m
        return 6
      end
    end

    def sketchup_length_unit
      case Sketchup.active_model.options["UnitsOptions"]["LengthFormat"]
      when 0
        return 2 #decimal
      when 1
        return 4 #architectural
      when 2
        return 3 #engineering
      when 3
        return 5 #fractional
      end
    end

    def sketchup_measurement
      case Sketchup.active_model.options["UnitsOptions"]["LengthFormat"]
      when 0
        return 1 #decimal = metric
      when 1
        return 0 #architectural = english
      when 2
        return 0 #engineering = english
      when 3
        return 0 #fractional = english
      end
    end

    def sketchup_length_unit_precision
      Sketchup.active_model.options["UnitsOptions"]["LengthPrecision"]
    end

    # dxf angle units
    # 0 = decimal degrees
    # 1 = deg/min/sec
    # 2 = grads
    # 3 = radians
    def sketchup_angle_unit
      0 #decimal degrees
    end

    def sketchup_angle_unit_precision
      Sketchup.active_model.options["UnitsOptions"]["AnglePrecision"]
    end

    def objects
      group(0, 'SECTION')
      group(2, 'OBJECTS')

      dictionary

      group(0, 'ENDSEC')
    end

    def dictionary
      group(0, 'DICTIONARY')
      group(5, '28')
      group(330, '0')
      group(100, 'AcDbDictionary')

      group(3, 'ACAD_GROUP')
      group(350, '29')

      group(3, 'ACAD_IMAGE_VARS')
      group(350, '2A')

      group(3, 'ACAD_MLINESTYLE')
      group(350, '2B')

      group(3, 'ACAD_SCALELIST')
      group(350, '2C')

      group(3, 'ACDBVARIABLEDICTIONARY')
      group(350, '2D')

      group(3, 'APPDATA')
      group(350, '2E')

      group(3, 'DWGPROPS')
      group(350, '2F')

      group(0, 'DICTIONARY')
      group(5, '29')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbDictionary')

      group(0, 'RASTERVARIABLES')
      group(5, '2A')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbRasterVariables')
      group(90, 0)
      group(70, 1)
      group(71, 1)
      group(72, 5)

      group(0, 'DICTIONARY')
      group(5, '2B')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbDictionary')
      group(3, 'STANDARD')
      group(350, '30')

      group(0, 'DICTIONARY')
      group(5, '2C')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbDictionary')

      group(0, 'DICTIONARY')
      group(5, '2D')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbDictionary')
      group(3, 'DIMASSOC')
      group(350, '31')
      group(3, 'HIDETEXT')
      group(350, '32')

      group(0, 'DICTIONARY')
      group(5, '2E')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbDictionary')

      group(0, 'XRECORD')
      group(5, '2F')
      group(102, '{ACAD_REACTORS')
      group(330, '28')
      group(102, '}')
      group(330, '28')
      group(100, 'AcDbXrecord')

      group(0, 'MLINESTYLE')
      group(5, '30')
      group(102, '{ACAD_REACTORS')
      group(330, '2B')
      group(102, '}')
      group(330, '2B')
      group(100, 'AcDbMlineStyle')
    end

    def classes
      group(0, 'SECTION')
      group(2, 'CLASSES')

      lwpolyline_class
      hatch_class

      group(0, 'ENDSEC')
    end

    def lwpolyline_class
      group(0, 'CLASS')
      group(1, 'LWPOLYLINE')
      group(2, 'AcDbPolyline')
      group(3, 'ObjectDBX Classes')
      group(90, 0)
      group(91, 0)
      group(280, 0)
      group(281, 1)
    end

    def hatch_class
      group(0, 'CLASS')
      group(1, 'HATCH')
      group(2, 'AcDbHatch')
      group(3, 'ObjectDBX Classes')
      group(90, 0)
      group(91, 0)
      group(280, 0)
      group(281, 1)
    end

    def tables
      group(0, 'SECTION')
      group(2, 'TABLES')

      vport_table
      ltype_table
      layer_table
      style_table
      view_table
      ucs_table
      dimstyle_table
      block_record_table
      appid_table

      group(0, 'ENDSEC')
    end

    def vport_table
      group(0, 'TABLE')
      group(2, 'VPORT')
      group(5, '1')
      group(330, '0')
      group(100, 'AcDbSymbolTable')
      group(70, 1)
      group(0, 'VPORT')
      group(5, '2')
      group(330, '1')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbViewportTableRecord')
      group(2, '*ACTIVE')
      group(70, 0)
      group(10, 0.0)
      group(20, 0.0)
      group(11, 1.0)
      group(21, 1.0)
      group(12, (@min[0] + @max[0])/2)
      group(22, (@min[1] + @max[1])/2)
      group(40, (@max[1] - @min[1]) * 1.25)
      group(41, ( (@max[0] - @min[0]) / (@max[1] - @min[1])))  #Viewport aspect ratio
      group(0, 'ENDTAB')
    end

    def ltype_table
      shortdash = 0.0525
      dash = 0.07874
      space = 0.07874
      shortspace = 0.0525
      dot = 0
      longdash = 0.11811

      group(0, 'TABLE')
      group(2, 'LTYPE')
      group(5, '3')
      group(100, 'AcDbSymbolTable')
      group(70, 3)
      group(0, 'LTYPE')
      group(5, '4')
      group(330, '3')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbLinetypeTableRecord')
      group(2, 'ByBlock')
      group(70, 0)
      group(3, '')
      group(72, 65)
      group(73, 0)
      group(40, 0.0)
      group(0, 'LTYPE')
      group(5, '5')
      group(330, '3')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbLinetypeTableRecord')
      group(2, 'ByLayer')
      group(70, 0)
      group(3, '')
      group(72, 65)
      group(73, 0)
      group(40, 0.0)
      group(0, 'LTYPE')
      group(5, '6')
      group(330, '3')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbLinetypeTableRecord')
      group(2, 'CONTINUOUS')
      group(70, 0)
      group(3, 'Solid line')
      group(72, 65)
      group(73, 0)
      group(40, 0.0)


        group(0, 'LTYPE')
        group(5, '7')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DASHED')
        group(70, 0)
        group(3, 'Dashed __ __ __ __ __ __ __ __ __ __ __ __ __ __')
        group(72, 65)
        group(73, 2)
        group(40, (dash + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, '8')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'SHORT_DASH')
        group(70, 0)
        group(3, 'Short dash __ __ __ __ __ __ __ __ __ __ __ __ __ __')
        group(72, 65)
        group(73, 2)
        group(40, (shortdash + shortspace) * @scale)
        group(49, shortdash * @scale)
        group(74, 0)
        group(49, -shortspace * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, '9')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DASH')
        group(70, 0)
        group(3, 'Dash __ __ __ __ __ __ __ __ __ __ __ __ __ _')
        group(72, 65)
        group(73, 2)
        group(40, (dash + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, 'A')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DASH_DOT')
        group(70, 0)
        group(3, 'Dash dot __ . __ . __ . __ . __ . __ . __ . __')
        group(72, 65)
        group(73, 4)
        group(40, (dash + space + dot + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, 'B')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DOT')
        group(70, 0)
        group(3, 'Dot . . . . . . . . . . . . . . . . . . . . . . . .')
        group(72, 65)
        group(73, 2)
        group(40, (dot + shortspace) * @scale)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -shortspace * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, 'C')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DASH_DOUBLE-DOT')
        group(70, 0)
        group(3, 'Dash double-dot ____ . . ____ . . ____ . . ____ . . ____')
        group(72, 65)
        group(73, 6)
        group(40, (dash + space + dot + space + dot + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, 'D')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DASH_TRIPLE-DOT')
        group(70, 0)
        group(3, 'Dash triple-dot ____ ... ____ ... ____')
        group(72, 65)
        group(73, 8)
        group(40, (dash + space + dot + space + dot + space + dot + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, 'E')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DOUBLE-DASH_DOT')
        group(70, 0)
        group(3, 'Double-dash dot __ __ . __ __ . __ __ . __ __ . __ __ .')
        group(72, 65)
        group(73, 6)
        group(40, (dash + space + dash + space + dot + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, 'F')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DOUBLE-DASH_DOUBLE-DOT')
        group(70, 0)
        group(3, 'Double-dash double-dot __ __ . . __ __ . . _')
        group(72, 65)
        group(73, 8)
        group(40, (dash + space + dash + space + dot + space + dot + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, '10')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'DOUBLE-DASH_TRIPLE-DOT')
        group(70, 0)
        group(3, 'Double-dash triple-dot __ __ . . . __ __ . .')
        group(72, 65)
        group(73, 10)
        group(40, (dash + space + dash + space + dot + space + dot + space + dot + space) * @scale)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dot * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, '11')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'LONG-DASH_DASH')
        group(70, 0)
        group(3, 'Long-dash dash ____ _ ____ _ ____ _ ____ _ ____ _ ____')
        group(72, 65)
        group(73, 4)
        group(40, (longdash + space + dash + space) * @scale)
        group(49, longdash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)

        group(0, 'LTYPE')
        group(5, '12')
        group(330, '3')
        group(100, 'AcDbSymbolTableRecord')
        group(100, 'AcDbLinetypeTableRecord')
        group(2, 'LONG-DASH_DOUBLE-DASH')
        group(70, 0)
        group(3, 'Long-dash double-dash ______  __  __  ______  __  __  ______')
        group(72, 65)
        group(73, 6)
        group(40, (longdash + space + dash + space + dash + space) * @scale)
        group(49, longdash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)
        group(49, dash * @scale)
        group(74, 0)
        group(49, -space * @scale)
        group(74, 0)


      group(0, 'ENDTAB')
    end

    def layer_table
      group(0, 'TABLE')
      group(2, 'LAYER')
      group(5, '14')
      group(100, 'AcDbSymbolTable')
      group(70, 1)
      group(0, 'LAYER')
      group(5, '15')
      group(330, '14')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbLayerTableRecord')
      group(2, '0')
      group(70, 0)
      group(62, 7)
      group(6, 'Continuous')
      group(370,-3)
      group(390,'F')
      group(0, 'ENDTAB')
    end

    def style_table
      group(0, 'TABLE')
      group(2, 'STYLE')
      group(5, '16')
      group(100, 'AcDbSymbolTable')
      group(70, 1)
      group(0, 'STYLE')
      group(5, '17')
      group(330, '16')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbTextStyleTableRecord')
      group(2, 'Standard')
      group(70, 0)
      group(40, 0)
      group(41, 1.0)
      group(50, 0.0)
      group(71, 0)
      group(42, 0.2)
      group(3, 'Arial.ttf')
      group(4, '')
      group(0, 'ENDTAB')
    end

    def view_table
      group(0, 'TABLE')
      group(2, 'VIEW')
      group(5, '18')
      group(100, 'AcDbSymbolTable')
      group(70, 0)
      group(0, 'ENDTAB')
    end

    def ucs_table
      group(0, 'TABLE')
      group(2, 'UCS')
      group(5, '19')
      group(100, 'AcDbSymbolTable')
      group(70, 0)
      group(0, 'ENDTAB')
    end

    def dimstyle_table
      group(0, 'TABLE')
      group(2, 'DIMSTYLE')
      group(5, '1A')
      group(100, 'AcDbSymbolTable')
      group(70, 1)
      group(100, 'AcDbDimStyleTable')
      group(0, 'DIMSTYLE')
      group(105, '1B')
      group(330, '1A')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbDimStyleTableRecord')
      group(2, 'STANDARD')
      group(70, 0)
      group(0, 'ENDTAB')
    end

    def block_record_table
      group(0, 'TABLE')
      group(2, 'BLOCK_RECORD')
      group(5, '1C')
      group(100, 'AcDbSymbolTable')
      group(70, 3)
      group(0, 'BLOCK_RECORD')
      group(5, '1D')
      group(330, '1C')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbBlockTableRecord')
      group(2, '*Model_Space')
      group(0, 'BLOCK_RECORD')
      group(5, '1E')
      group(330, '1C')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbBlockTableRecord')
      group(2, '*Paper_Space')
      group(0, 'BLOCK_RECORD')
      group(5, '1F')
      group(330, '1C')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbBlockTableRecord')
      group(2, '*Paper_Space0')
      group(0, 'ENDTAB')
    end

    def appid_table
      group(0, 'TABLE')
      group(2, 'APPID')
      group(5, '20')
      group(100, 'AcDbSymbolTable')
      group(70, 1)
      group(0, 'APPID')
      group(5, '21')
      group(330, '20')
      group(100, 'AcDbSymbolTableRecord')
      group(100, 'AcDbRegAppTableRecord')
      group(2, 'ACAD')
      group(70, 0)
      group(0, 'ENDTAB')
    end

    def blocks
      group(0, 'SECTION')
      group(2, 'BLOCKS')
      group(0, 'BLOCK')
      group(5, '22')
      group(330, '1C')
      group(100, 'AcDbEntity')
      group(8, '0')
      group(100, 'AcDbBlockBegin')
      group(2, '*Model_Space')
      group(70, 0)
      group(10, 0.0)
      group(20, 0.0)
      group(30, 0.0)
      group(3, '*Model_Space')
      group(1, '')
      group(0, 'ENDBLK')
      group(5, '23')
      group(330, '22')
      group(100, 'AcDbEntity')
      group(8, '0')
      group(100, 'AcDbBlockEnd')

      group(0, 'BLOCK')
      group(5, '24')
      group(330, '1D')
      group(100, 'AcDbEntity')
      group(8, '0')
      group(100, 'AcDbBlockBegin')
      group(2, '*Paper_Space')
      group(70, 0)
      group(10, 0.0)
      group(20, 0.0)
      group(30, 0.0)
      group(3, '*Paper_Space')
      group(1, '')
      group(0, 'ENDBLK')
      group(5, '25')
      group(330, '24')
      group(100, 'AcDbEntity')
      group(8, '0')
      group(100, 'AcDbBlockEnd')

      group(0, 'BLOCK')
      group(5, '26')
      group(330, '1E')
      group(100, 'AcDbEntity')
      group(8, '0')
      group(100, 'AcDbBlockBegin')
      group(2, '*Paper_Space0')
      group(70, 0)
      group(10, 0.0)
      group(20, 0.0)
      group(30, 0.0)
      group(3, '*Paper_Space0')
      group(1, '')
      group(0, 'ENDBLK')
      group(5, '27')
      group(330, '26')
      group(100, 'AcDbEntity')
      group(8, '0')
      group(100, 'AcDbBlockEnd')

      group(0, 'ENDSEC')
    end

    def polygon(loop, fill_handle, hatch_handle, layer, lineweight=nil)
      save_layer = Skalp.layer_check(layer)
      group(0, 'LWPOLYLINE')
      group(5, loop.handle.to_s) #handle
      group(102, '{ACAD_REACTORS') if fill_handle || hatch_handle
      group(330, fill_handle.to_s) if fill_handle
      group(330, hatch_handle.to_s) if hatch_handle
      group(102, '}') if fill_handle || hatch_handle
      group(100, 'AcDbEntity')
      #group(8,'Skalp-polygon')
      group(8, layer)
      group(100, 'AcDbPolyline')
      group(90, loop.vertices.size) #Number of vertices.
      group(70, 1)
      loop.vertices.each do |point|
        group(10, Skalp::inch_to_modelunits(point[0]))
        group(20, Skalp::inch_to_modelunits(point[1]))
      end
      group(370, lineweight) if lineweight
    end

    def open_polygon(array, line_type = nil, layer, color, colortype)

      group(0, 'LWPOLYLINE')
      group(5, next_handle.to_s) #handle
      group(6, line_type) if line_type
      group(100, 'AcDbEntity')
      group(8, layer)
      group(colortype, color)
      group(100, 'AcDbPolyline')
      group(90, array.size) #Number of vertices.
      group(70, 0)
      array.each do |point|
        group(10, Skalp::inch_to_modelunits(point[0]))
        group(20, Skalp::inch_to_modelunits(point[1]))
      end
    end

    def line(line, line_type = nil, layer)
      save_layer = Skalp.layer_check(layer)
      group(0, 'LINE')
      group(5, next_handle.to_s) #handle
      #group(330, next_handle.to_s)
      group(6, line_type) if line_type
      group(100, 'AcDbEntity')
      group(8, layer)
      group(100, 'AcDbLine')
      group(62, 7)
      group(10, Skalp::inch_to_modelunits(line[0][0]))
      group(20, Skalp::inch_to_modelunits(line[0][1]))
      group(11, Skalp::inch_to_modelunits(line[1][0]))
      group(21, Skalp::inch_to_modelunits(line[1][1]))
    end

    def hatch(hatched_polygon, hatch_handle, hatch, layer)
      group(0, 'HATCH')
      group(5, hatch_handle.to_s)
      group(100, 'AcDbEntity')
      group(8, layer)
      group(370, hatched_polygon.hatch_lineweight) if hatched_polygon.hatch_lineweight
      group(420, hatched_polygon.linecolor) if hatched_polygon.linecolor != 7
      group(100, 'AcDbHatch')
      group(10, 0.0)
      group(20, 0.0)
      group(30, 0.0)
      group(210, 0.0)
      group(220, 0.0)
      group(230, 1.0)
      group(2, hatch.name) #Hatch pattern name
      group(70, 0) #Solid fill flag (solid fill = 1; pattern fill = 0)
      group(71, 1) #Associativity flag (associative = 1; non-associative = 0)
      group(91, hatched_polygon.innerloops.size + 1) #Number of boundary paths (loops)

      #Boundary_path
      boundary_path(hatched_polygon.outerloop, 'outerloop', hatched_polygon.outerloop.handle)
      hatched_polygon.innerloops.each { |innerloop| boundary_path(innerloop, 'innerloop', innerloop.handle) }

      group(75, 0) #Hatch style   0 = hatch "odd parity" area (Normal style) 1 = hatch outermost area only (Outer style) 2 = hatch through entire area (Ignore style)
      group(76, 2) #Hatch pattern type  0 = user-defined 1 = predefined  2 = custom
      group(52, 0) #Hatch pattern angle (pattern fill only)
      group(41, 1) #Hatch pattern scale or spacing (pattern fill only)
      group(77, 0) #Hatch pattern double flag (double = 1, not double = 0). (pattern fill only)

      #export_pat_file(hatch)
      group(78, hatch.hatchlines.size) #Pattern line data. Repeats number of times specified by code 78. See "Pattern Data."

      #hatchpatterns
      hatch.hatchlines.each do |hatchline|
        group(53, hatchline.degangle) #Pattern line angle
        group(43, hatchline.xorig) #Pattern line base point, X component
        group(44, hatchline.yorig) #Pattern line base point, Y component
        group(45, hatchline.get_xoffset) #Pattern line offset, X component
        group(46, hatchline.get_yoffset) #Pattern line offset, Y component
        group(79, hatchline.line_style_def.size) #Number of dash length items

        hatchline.line_style_def.each do |dash|
          group(49, dash)
        end
      end
      group(47, 0.0) #Pixel size
      group(98, 0) #Number of seed points
    end

    def export_pat_file(hatch)
      filepath = @export_path + "#{hatch.name}.pat"
      @pat = File.open(filepath, "wb")
      @pat.printf "%s\r\n", "*#{hatch.name}"

      hatch.hatchlines.each do |hatchline|
        hatch_string = "#{hatchline.degangle}, #{hatchline.xorig}, #{hatchline.yorig}, #{hatchline.get_xoffset}, #{hatchline.get_yoffset}"

        line_string = ""
        hatchline.line_style_def.each do |dash|
          (line_string == "") ?
              line_string = dash.to_s :
              line_string = line_string + ', ' + dash.to_s
        end
        hatch_string = hatch_string + ", " + line_string if line_string != ""

        @pat.printf "%s\r\n", hatch_string
      end

      @pat.close
    end

    def fill(hatched_polygon, hatch_handle, color, layer)
      group(0, 'HATCH')
      group(5, hatch_handle.to_s)
      group(100, 'AcDbEntity')
      group(8, layer)
      group(420,color)
      group(100, 'AcDbHatch')
      group(10, 0.0)
      group(20, 0.0)
      group(30, 0.0)
      group(210, 0.0)
      group(220, 0.0)
      group(230, 1.0)
      group(2, 'SOLID') #Hatch pattern name
      group(70, 1) #Solid fill flag (solid fill = 1; pattern fill = 0)
      group(71, 1) #Associativity flag (associative = 1; non-associative = 0)
      group(91, hatched_polygon.innerloops.size + 1) #Number of boundary paths (loops)

      #Boundary_path
      boundary_path(hatched_polygon.outerloop, 'outerloop', hatched_polygon.outerloop.handle)
      hatched_polygon.innerloops.each { |innerloop| boundary_path(innerloop, 'innerloop', innerloop.handle) }

      group(75, 0) #Hatch style   0 = hatch "odd parity" area (Normal style) 1 = hatch outermost area only (Outer style) 2 = hatch through entire area (Ignore style)
      group(76, 1) #Hatch pattern type  0 = user-defined 1 = predefined  2 = custom
      group(47, 0.0) #Pixel size
      group(98, 0) #Number of seed points
    end

    def boundary_path(loop, type, polygon_handle)
      type == 'outerloop' ? group(92, 22) : group(92, 7) #Boundary path type flag (bit coded) 0 = default 1 = external 2 = polyline 4= derived 8 = textbox 16 = outermost
      group(72, 0) #Edge type (only if boundary is not a polyline)

      #boundary edges
      group(73, 1) #Is closed flag
      group(93, loop.vertices.size) #Number of polyline vertices

      loop.vertices.each do |point|
        group(10, Skalp::inch_to_modelunits(point[0]))
        group(20, Skalp::inch_to_modelunits(point[1]))
      end

      group(97, 1) #Number of source boundary objects
      group(330, polygon_handle.to_s) #Reference to source boundary objects (multiple entries)
    end

    def entities
      group(0, 'SECTION')
      group(2, 'ENTITIES')

      # do entities

      @reversed_lines_by_layer.each do |layer, lines|
        next unless lines

        layer_linestyles = Skalp::get_rearview_linestyle_by_tag
        linestyle = layer_linestyles[layer.name]
        linestyle = @reversed_linetype unless linestyle

        if @rear_layer == 'fixed'
          layer_string = 'SKALP-REAR'
        else
          layer_string = "#{Skalp.layer_check(layer.name)}#{@rear_suffix}"
        end

        case @rear_color
          when 'black'
            colortype = 62
            color = 7
          when 'bylayer'
            colortype = 62
            color = 256
          when 'layers'
            su_color = layer.color
            colortype = 420
            color = rgb2truecolor(su_color.red, su_color.green, su_color.blue)
          else
            colortype = 62
            color = 7
        end

        lines.all_curves.each do |line|
          open_polygon(line, linestyle, layer_string, color, colortype)
        end
      end

      @forward_lines_by_layer.each do |layer, lines|
        next unless lines

        if @forward_layer == 'fixed'
          layer_string = 'SKALP-FORWARD'
        else
          layer_string = "#{Skalp.layer_check(layer.name)}#{@forward_suffix}"
        end

        case @forward_color
          when 'black'
              colortype = 62
              color = 7
          when 'bylayer'
              colortype = 62
              color = 256
          when 'layers'
              su_color = layer.color
              colortype = 420
              color = rgb2truecolor(su_color.red, su_color.green, su_color.blue)
          else
              colortype = 62
              color = 7
        end

        lines.all_curves.each do |line|
          lstyle = layer.line_style.name.gsub(' ', '_').upcase if layer.line_style
          open_polygon(line, lstyle, layer_string, color, colortype)
        end
      end

      @hatched_polygons.each do |hatched_polygon|
        fill_handle = next_handle if hatched_polygon.has_fill
        hatch_handle = next_handle if hatched_polygon.has_hatch

        hatched_polygon.outerloop.handle = next_handle
        hatched_polygon.innerloops.each { |innerloop|
          innerloop.handle = next_handle
        }

        layer = Skalp.layer_check(hatched_polygon.layer)
        section_layer = "#{layer}#{@section_suffix}"
        fill_layer = "#{layer}#{@fill_suffix}"
        hatch_layer = "#{layer}#{@hatch_suffix}"

        fill(hatched_polygon, fill_handle, hatched_polygon.fillcolor, fill_layer) if hatched_polygon.has_fill
        hatch(hatched_polygon, hatch_handle, hatched_polygon.hatch, hatch_layer) if hatched_polygon.has_hatch

        polygon(hatched_polygon.outerloop, fill_handle, hatch_handle, section_layer, hatched_polygon.lineweight)

        hatched_polygon.innerloops.each { |innerloop|
          polygon(innerloop, fill_handle, hatch_handle, section_layer, hatched_polygon.lineweight)
        }
      end

      group(0, 'ENDSEC')
    end
  end
end
