# Skalp Patterns - plugin for SketchUp.
#
# Creates tilable png textures for use in SketchUp and Layout. Imports pattern definitions
# from standard ACAD.PAT pattern files.
#
# @author Skalp (C) 2014

module Skalp
  module SkalpHatch

    class HatchLine
      attr_reader :radangle, :xoffset, :yoffset, :line_style_def, :line_style_length, :xbbox, :ybbox, :name, :hatchlineoverflow,
                  :line_rotation_transformation, :linestyle_translation, :hatchdef, :line, :line_style_length_vector
      attr_accessor :original_line

      def initialize(hatchdef, line = [0, 0, 0, 0, 0], processedline)
        @original_line = line
        line = processedline
        @radangle = SkalpHatch.radians(line[0])
        @basepoint = Point2D.new(line[1], line[2])
        @xoffset = line[3]
        @yoffset = line[4]
        @line_style_def = line[5..-1] if line[5..-1]
        @line_style_def = [] if @line_style_def == [] || @line_style_def.sort.first > 0.0 #treat linestyles without pen-up as continous
        @name = hatchdef.name
        @hatchdef = hatchdef
        @hatchlineoverflow = false
      end

      # only used in DXF export
      def degangle
        SkalpHatch.degrees(@radangle)
      end

      def xorig
        @basepoint.x
      end

      def yorig
        @basepoint.y
      end

      def update_tiling_size(for_tilable_tile = true)
        if @line_style_def != [] # has line_style
          @line_style_length = line_style_def.inject(0) { |sum, number| sum.abs + number.abs } #TODO detecteer repetitie in lijnstijl en verklein de lengte respectivelijk
          @t = 1.0e-11

          x_comp = Math.cos(radangle) * @line_style_length
          y_comp = Math.sin(radangle) * @line_style_length
          x_comp.abs > @t ? x = x_comp : x = 0.0
          y_comp.abs > @t ? y = y_comp : y = 0.0

          @line_style_length_vector = Vector2D.new(Point2D.new(x, y))
          offset_vector = Vector2D.new(Point2D.new(get_xoffset, get_yoffset))
          if for_tilable_tile
            tile_factors(line_style_length_vector, offset_vector)
          else
            return [x.abs, y.abs]
          end

        else # has no line_style
          av = Vector2D.new(@radangle)
          xv = Vector2D.new(Point2D.new(1.0, 0.0))
          yv = Vector2D.new(Point2D.new(0.0, 1.0))
          if (av.dot(xv)).abs < 1.0e-10 # ||Y-axis
            @line = Line2D.new(Point2D.new(xorig, yorig), Vector2D.new(@radangle))
            @xbbox = @line_style_length = @yoffset
            @ybbox = 0.0
          elsif (av.dot(yv)).abs < 1.0e-10 # ||X-axis
            @line = Line2D.new(Point2D.new(xorig, yorig), Vector2D.new(@radangle))
            @xbbox = 0.0
            @ybbox = @line_style_length = @yoffset
          else
            @line_style_length = continuous_line_style_length
            @xbbox = (Math.cos(radangle).to_f * line_style_length).abs
            @ybbox = (Math.sin(radangle).to_f * line_style_length).abs
          end
        end

        @xbbox = @xbbox.abs
        @ybbox = @ybbox.abs

        #@relevance = get_relevance   #TODO relevance
        [xbbox, ybbox]
      end

      def rotate!(degrees)
        radians = SkalpHatch.radians(degrees)
        @radangle += radians
        rotation = Transformation2D.new.rotation(SkalpHatch.radians(degrees))
        @basepoint.transform!(rotation)
        update_tiling_size(false)
      end

      # Attention: only to be used for DXF export. Do NOT try to create anything tilable from a translated HatchDefinition instance, you will blow a fuse!
      def translate!(x, y)
        @basepoint.x += x
        @basepoint.y += y
      end

      # Attention: only to be used for DXF export. Do NOT try to create anything tilable from a scaled HatchDefinition instance, you will blow a fuse!
      def scale!(factor)
        @basepoint.x *= factor
        @basepoint.y *= factor
        @xoffset *= factor
        @yoffset *= factor
        @line_style_def.map! { |dash| dash *= factor }
      end

      def line_style_entities #starts at 0,0
        origin_trans = Transformation2D.new.translation(@basepoint.x, @basepoint.y)
        @line_rotation_transformation = Transformation2D.new.rotation(radangle)
        @line = Line2D.new(Point2D.new(xorig, yorig), Vector2D.new(@radangle))

        if @line_style_def == [] || !@line_style_def
          [Line2D.new(@line.p1, @line.p2)] # return continuous line
        else
          lines_array = []
          x = 0.0
          @line_style_def.each do |ls|
            if ls == 0.0
              lines_array << SkalpHatch::Point2D.new(x, 0.0)
            elsif ls < 0
              x += ls.abs
            else
              x2 = x + ls
              lines_array << Edge2D.new(Point2D.new(x, 0.0), Point2D.new(x2, 0.0))
              x += ls
            end
          end

          lines_array.map! do |e|
            e.transform!(@line_rotation_transformation)
            e.transform!(origin_trans)
          end

          lines_array #return an array with Edge2D and/or point2D Objects
        end
      end

      def get_relevance
        return

        #work in progress here
        ls = @line_style_def.dup
        if ls.size <= 1 #patterns without linestyle, with only one 'value' are irrelevant
          0.0
        else
          case ls[0] <=> 0.0
            when -1 || 0 # rotate linestyle until it starts with a dash
              until ls[0] > 0
                ls = ls.push(ls.shift) # equivalent of Array.rotate, but that is not implemented in ruby 1.8
              end
          end

          @line_style_def[0..-2].inject(0) { |sum, i| sum.abs + i.abs } / @line_style_def[-1].abs
        end
      end

      def tile_factors(v1, v2)

        to_clip = true
        xbbox_ok = []
        ybbox_ok = []

        max_res = @hatchdef.ppi.to_i
        decrement = 50
        min_res = 150
        step = (max_res - min_res) / decrement

        for res_factor in 0..step

          res = max_res - (res_factor * decrement) #TODO res nog te gebruiken    bij lagere res
          max = SkalpHatch.clipsize.to_f/(SkalpHatch.user_input[:user_x] / @hatchdef.def_x * res)

          @ybbox = @xbbox = max

          next if v1.x >= max || v1.y >= max || v2.x >= max || v2.y >= max

          #begin inner loops
          @overflow = false
          factor = 1
          while @ybbox >= max && @overflow == false
            x = tile_factor(v1.x, v2.x, factor)
            v1, v2 = v2, v1 if x[2]
            @ybbox = x[0]*v1.y.abs + x[1]*v2.y.abs
            factor *= 2
          end
          @hatchlineoverflow = true if @overflow

          @overflow = false
          factor = 1
          while @xbbox >= max && @overflow == false
            y = tile_factor(v1.y, v2.y, factor)
            v1, v2 = v2, v1 if y[2]
            @xbbox = y[0]*v1.x.abs + y[1]*v2.x.abs
            factor *= 2
          end
          @hatchlineoverflow = true if @overflow
          #end inner loops

          xbbox_ok = [@xbbox, @ybbox, res] if @xbbox < max
          ybbox_ok = [@ybbox, @xbbox, res] if @ybbox < max

          if @xbbox < max && @ybbox < max
            to_clip = false
            break
          end
        end

        if to_clip
          if xbbox_ok[2] < ybbox_ok[2]
            @xbbox = xbbox_ok[0]
            xbbox_ok[1] < max ? @ybbox = xbbox_ok[1] : @ybbox = max
          else
            @ybbox = ybbox_ok[0]
            ybbox_ok[1] < max ? @xbbox = ybbox_ok[1] : @xbbox = max
          end
        else

          if res < @hatchdef.ppi
            @hatchdef.ppi = res
            @hatchdef.update_tile_size # RESTART
          end
        end
      rescue
        @xbbox = max
        @ybbox = max
      end

      def tile_factor(a, b, factor)
        a = a.abs
        b = b.abs
        tolerance = 5.0e-4 * factor
        #OPMERKING: TOLERANTIE PROCENTUEEL OF RELATIEF TE MAKEN?
        raise 'error' if a == 0 && b == 0
        return [0, 1, false] if b < tolerance
        return [1, 0, false] if a < tolerance

        switchvectors = false
        case a <=> b
          when -1
            a, b = b, a
            switchvectors = true
        end

        m = n = 0
        t = a

        until t.abs < tolerance
          m += 1
          until t <= 0 || t.abs < tolerance
            n += 1
            t = t - b
            return [m, n] if m == 20 || n == 20
          end
          t = t + a if t.abs > tolerance
        end
        [m, n, switchvectors]
      end

      # return x coordinate component of the offset vector with respect to the hatchline origin
      # @xoffset value in the definition is defined in a local coordinate system ALONG the hatchline
      def get_xoffset
        x = (Math.cos(@radangle) * @xoffset) + (Math.cos(@radangle + Math::PI / 2) * @yoffset)
        x.abs > 1.0e-11 ? x : 0.0
      end

      # return y coordinate component of the offset vector with respect to the hatchline origin
      # @yoffset value in the definition is defined in a local coordinate system PERPENDICULAR to the hatchline
      def get_yoffset
        y = (Math.sin(@radangle) * @xoffset) + (Math.sin(@radangle + Math::PI / 2) * @yoffset)
        y.abs > 1.0e-11 ? y : 0.0
      end

      def continuous_line_style_length #only called for sloped lines
        @line = Line2D.new(Point2D.new(get_xoffset, get_yoffset), Vector2D.new(@radangle))
        p1x = line.p_on_x
        p2y = line.p_on_y
        if p1x && p2y
          p1x.distance(p2y)
        else
          0.0 #OPMERKING: check andere scenario's  voor line evenwijdig X of Y as en in combinatie door origin
        end
      end

      def self.preprocesshatchline (linefromfile)
        linefromfile.gsub(/\s+/, "").split(",").collect! { |e| ((e.to_s[0]=="." ? "0" : "") + e.to_s).to_f }
      end
    end #class HatchLine

  end
end
