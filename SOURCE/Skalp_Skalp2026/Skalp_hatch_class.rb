# Skalp Patterns - plugin for SketchUp.
#
# Creates tilable png textures for use in SketchUp and Layout. Imports pattern definitions
# from standard ACAD.PAT pattern files.
#
# @author Skalp (C) 2014

require "base64"

module Skalp
  module SkalpHatch
    # Hatch is a container class used to hold a Skalp Pattern together
    # implements methods to create previews and tileable png textures.
    class Hatch
      attr_accessor :hatchdefinition, :hatchtile, :def_x, :def_y, :def_offset # :def_x and :def_y are temporary helper sizes, not actual tile sizes
      attr_reader :tile_width, :tile_height, :pat_scale

      def add_hatchdefinition(hatchdef)
        @hatchdefinition = hatchdef
        def_dims = hatchdefinition.dimensions # get max linestyle projections
        @def_x = def_dims[0]
        @def_y = def_dims[1]
        @def_offset = def_dims[2]
      end

      def create_png(opts = {})
        @opts = { # default values:
          type: :preview,
          angle: 0, # rotation angle in degrees
          width: 215, # 170 # width       140    #incon preview: 70 x 35, drawing factor 80
          height: 100, # height     100
          solid_color: false,
          line_color: "rgb(0, 0, 0)",
          fill_color: "rgba(255, 255, 255, 1.0)",
          pen: 1.0 / 72, # pen_width in inch (1pt = 1.0 / 72)1.0 / 72       #(300.0/72) * 0.51 / 72
          section_cut_width: 1.0 / 72,
          resolution: 72,
          print_scale: 50, # e.g. 1, 10, 20, 50, 100, 500, 1000 for metric, 1, 12, 24, 48, 96 for imperial
          user_x: 1.5, # [0..2.36] inch
          zoom_factor: 0.5,
          space: :paperspace,
          section_line_color: "rgb(0, 0, 0)"
        }.merge(opts)

        if opts[:type] == :thumbnail
          @opts.merge!({
                         gauge: false,
                         resolution: 72,
                         print_scale: 50
                       })
        end

        @opts[:line_color] = "rgb(0, 0, 0)" if @opts[:solid_color] == true

        parse_colors

        SkalpHatch.user_input = @opts
        width = @opts[:width].to_f
        height = @opts[:height].to_f
        angle = @opts[:angle]
        pen_width = @opts[:pen].to_f
        resolution = @opts[:resolution]

        if @opts[:space] == :paperspace
          user_x = @opts[:user_x]
        else
          user_x = @opts[:user_x] = @opts[:user_x] / @opts[:print_scale]
          pen_width = @opts[:pen] = @opts[:pen] / @opts[:print_scale]
        end

        @zoom_factor = @opts[:zoom_factor]

        if %i[preview thumbnail].include?(@opts[:type]) # PREPARE FOR PREVIEW PNG

          # puts "PREVIEW_________________________#{hatchdefinition.name}"
          scale_factor = height * def_x / def_y < width ? height / def_y : width / def_x

          scale = scale_factor * @zoom_factor * hatchdefinition.def_normalisation

          # line widths in preview
          def_x_or_y = def_x == 0.0 ? def_y : def_x

          pen_width = ((def_x_or_y * (pen_width / user_x) * scale) / resolution)
          section_cut_width = (def_x_or_y * (@opts[:section_cut_width].to_f / user_x) * scale)

        else # PREPARE FOR TILEABLE PNG
          # puts "TILE____________________________#{hatchdefinition.name}"
          hatchdefinition.ppi = @opts[:resolution]
          hatchdefinition.print_scale = @opts[:print_scale]
          @hatchdefinition.update_tile_size

          def_x_or_y = def_x == 0.0 ? def_y : def_x

          # Guard for solid color patterns where def_x and def_y are both 0
          if def_x_or_y == 0.0 || @opts[:solid_color] == true
            # Use a fixed small tile for solid colors (no pattern to tile)
            width = 10.0
            height = 10.0
            scale = 1.0
            @comp_trans = Transformation2D.new.scaling(1.0, 1.0)
          else
            scale = user_x / def_x_or_y * resolution
            width = scale * hatchdefinition.definitionxbbox
            height = scale * hatchdefinition.definitionybbox

            # Prevent NaN or Division by Zero if width/height are invalid
            if width.nil? || width.nan? || width.abs < 0.0001 || height.nil? || height.nan? || height.abs < 0.0001
              @comp_trans = Transformation2D.new.scaling(1.0, 1.0)
            else
              # Create scaling transformation to compensate for integer canvas size versus real (float) canvas size.
              @comp_trans = Transformation2D.new.scaling(width.round(1).to_i / width, height.round(1).to_i / height)
            end
          end

          @zoom_factor = 1
          @tile_width = width
          @tile_height = height # feedback naar dialoog om SU material size te zetten        #TODO na te kijken
        end

        if SkalpHatch.develop
          if hatchdefinition.def_normalisation > 1
            puts "normalistatie: #{hatchdefinition.def_normalisation}"
            # return
            @opts[:fill_color] = ChunkyPNG::Color.rgba(255, 50, 50, 255)
            scale *= hatchdefinition.def_normalisation # FIXME: TEMPORARY HACK, PRODUCES NON TILING RESULT!
          else
            # return
          end
        elsif hatchdefinition.def_normalisation > 1
          # return
          scale *= hatchdefinition.def_normalisation
        else
          # return
        end

        # Guard against NaN/Infinity in scale and dimensions before creating transformations
        scale = safe_number(scale, 1.0)
        width = safe_number(width, 10.0)
        height = safe_number(height, 10.0)
        pen_width = safe_number(pen_width, 0.01)

        scale_trans = Transformation2D.new.scale!(scale)
        start_translation = Transformation2D.new.translate!(width * ((1 - @zoom_factor) / 2), height * ((1 - @zoom_factor) / 2)) # zoom_factor moet 1 zijn voor tile
        t = start_translation * scale_trans

        @hatchtile = HatchTile.new(width, height)

        @hatchtile.linethickness = pen_width * resolution
        pen_width *= resolution

        # puts "tiling canvas: #{width.to_i}, #{height.to_i}"
        if (width.to_i * height.to_i) < (3500 * 3500)
          png = ChunkyPNG::Image.new(width.round(1).to_i, height.round(1).to_i, @opts[:fill_color])
        else
          UI.messagebox(Skalp.translate("Texture area is too large! Please reduce its size and try again."))
          return
        end

        # SKIP drawing lines if it's a Solid Color or Cross/Insulation
        # We also check the pattern_type explicitly to prevent AutoCAD lines from showing up behind the X or Solid background
        suppress_hatch = @opts[:solid_color] == true || %w[solid cross
                                                           insulation].include?(@opts[:pattern_type].to_s)
        # puts "[SkalpHatch Debug] create_png: Suppress? #{suppress_hatch} (solid_color=#{@opts[:solid_color]}, type=#{@opts[:pattern_type]})"
        unless suppress_hatch
          @hatchdefinition.hatchlines.each do |hl|
            hl.rotate!(angle) unless angle == 0
            hl.line_style_entities.each do |dash|
              case dash
              when Edge2D
                dash.transform!(t)
                t1 = Transformation2D.new.translation(hl.get_xoffset * scale, hl.get_yoffset * scale)
                t2 = t1.dup.inverse

                newdash1 = dash.dup
                newdash2 = dash.dup.transform!(t2)

                started = false
                check1 = @hatchtile.direction_to(newdash1)
                check2 = @hatchtile.direction_to(newdash2)

                check3 = check1 * check2 == -1 # handle case:
                check4 = @hatchtile.direction_to(newdash1.dup.transform!(t1)) # dashes oposite and transformations reversed (away from hatchtile)
                check5 = @hatchtile.direction_to(newdash2.dup.transform!(t2)) #
                check6 = check4 * check5 == -1 #
                t1, t2 = t2, t1 if check3 && check6 && check1 == check4 && check2 == check5 #

                until started
                  while @hatchtile.direction_to(newdash1) == 0
                    started = true
                    repeat_dashes(newdash1.dup, pen_width, png, hl, scale) # ,t3
                    newdash1.transform!(t1)
                  end

                  newdash1.transform!(t1)

                  while @hatchtile.direction_to(newdash2) == 0
                    started = true
                    repeat_dashes(newdash2.dup, pen_width, png, hl, scale)
                    newdash2.transform!(t2)
                  end

                  newdash2.transform!(t2)

                  break if check1 != 0 && check1 * -1 == @hatchtile.direction_to(newdash1)
                  break if check2 != 0 && check2 * -1 == @hatchtile.direction_to(newdash2)
                end

              when Point2D

                point = dash.transform!(t)
                pointline = hl.line.dup.transform!(t)

                t1 = Transformation2D.new.translation(hl.get_xoffset * scale, hl.get_yoffset * scale)
                t2 = t1.dup.inverse

                pointline1 = pointline.dup
                newpoint1 = point.dup

                pointline2 = pointline.dup.transform!(t2)
                newpoint2 = point.dup.transform!(t2)

                started = false
                check1 = @hatchtile.direction_to(pointline1)
                check2 = @hatchtile.direction_to(pointline2)

                check3 = check1 * check2 == -1 # handle case:
                check4 = @hatchtile.direction_to(pointline1.dup.transform!(t1)) # points oposite and transformations reversed (away from hatchtile)
                check5 = @hatchtile.direction_to(pointline2.dup.transform!(t2)) #
                check6 = check4 * check5 == -1 #
                t1, t2 = t2, t1 if check3 && check6 && check1 == check4 && check2 == check5 #

                until started

                  while @hatchtile.direction_to(pointline1) == 0
                    started = true
                    repeat_points(newpoint1.dup, pointline1.dup, pen_width, png, hl, scale) # ,t3
                    pointline1.transform!(t1)
                    newpoint1.transform!(t1)
                  end

                  pointline1.transform!(t1)
                  newpoint1.transform!(t1)

                  while @hatchtile.direction_to(pointline2) == 0
                    started = true
                    repeat_points(newpoint2.dup, pointline2.dup, pen_width, png, hl, scale)
                    pointline2.transform!(t2)
                    newpoint2.transform!(t2)
                  end

                  pointline2.transform!(t2)
                  newpoint2.transform!(t2)

                  break if check1 != 0 && check1 * -1 == @hatchtile.direction_to(pointline1)
                  break if check2 != 0 && check2 * -1 == @hatchtile.direction_to(pointline2)
                end

              when Line2D

                dash.transform!(t)
                t1 = Transformation2D.new.translation(hl.get_xoffset * scale, hl.get_yoffset * scale)
                t2 = t1.dup.inverse

                newdash1 = dash.dup
                newdash2 = dash.dup.transform!(t2)

                started = false

                check1 = @hatchtile.direction_to(newdash1)
                check2 = @hatchtile.direction_to(newdash2)

                check3 = check1 * check2 == -1 # handle case:
                check4 = @hatchtile.direction_to(newdash1.dup.transform!(t1)) # lines oposite and transformations reversed (away from hatchtile)
                check5 = @hatchtile.direction_to(newdash2.dup.transform!(t2)) #
                check6 = check4 * check5 == -1 #
                t1, t2 = t2, t1 if check3 && check6 && check1 == check4 && check2 == check5 #

                while !started || @hatchtile.direction_to(newdash1) == 0 || @hatchtile.direction_to(newdash2) == 0
                  if @hatchtile.direction_to(newdash1) == 0
                    started = true
                    draw_an_edge_or_line(@hatchtile.intersect(newdash1), pen_width, png)
                  end
                  newdash1.transform!(t1)

                  if @hatchtile.direction_to(newdash2) == 0
                    started = true
                    draw_an_edge_or_line(@hatchtile.intersect(newdash2), pen_width, png)
                  end

                  newdash2.transform!(t2)

                  break if check1 != 0 && check1 * -1 == @hatchtile.direction_to(newdash1)
                  break if check2 != 0 && check2 * -1 == @hatchtile.direction_to(newdash2)
                end
              end
            end
            hl.rotate!(-angle) unless angle == 0
          end

          draw_gauges(png, t) if @opts[:type] == :preview && @opts[:gauge] == true # PREVIEW draw gauges
        end

        if @opts[:pattern_type] == "cross"
          draw_cross_pattern(png, pen_width)
        elsif @opts[:pattern_type] == "insulation"
          draw_insulation_pattern(png, pen_width, @opts[:insulation_style])
        end

        draw_section_cut(png, section_cut_width) if %i[preview thumbnail].include?(@opts[:type])
        save_png(png, hatchdefinition.name) if @opts[:type] == :tile # Only save to disk for tile type
        return to_base64_blob(png) if @opts[:type] == :thumbnail

        return { gauge_ratio: @def_y / @def_x, png_base64: to_base64_blob(png) } if @opts[:type] == :preview

        # puts  "user_x: #{user_x}", "def_x_or_y: #{def_x_or_y}"
        return unless @opts[:type] == :tile

        { gauge_ratio: @def_y / @def_x, original_definition: @hatchdefinition.originaldefinition,
          pat_scale: user_x / def_x_or_y }
      end

      def draw_gauges(png, t)
        point_outline_color = ChunkyPNG::Color::WHITE
        dot_color = ChunkyPNG::Color::BLACK
        outline_feather = 3.0
        penwidth_pixels = 4.0
        rad = penwidth_pixels / 2

        unless @def_x == 0.0
          x_gauge = Edge2D.new(Point2D.new(0.0, 0.0), Point2D.new(@def_x, 0.0)).transform!(t)
          red = ChunkyPNG::Color.rgba(162, 0, 0, 128)

          # white antialiased outline on gauge endpoints
          flip_vertical_png_coordinates(x_gauge, png)
          png.circle_float(x_gauge.p1, 3, point_outline_color, outline_feather) # X origin white antialiased outline
          png.circle_float(x_gauge.p2, 3, point_outline_color, outline_feather) # X right white antialiased outline
          flip_vertical_png_coordinates(x_gauge, png)

          draw_an_edge_or_line(x_gauge, penwidth_pixels, png, red)

          # black dots overdraw
          flip_vertical_png_coordinates(x_gauge, png)
          png.circle_float(x_gauge.p2, rad, dot_color, 1.1) # X right black dot overdraw
          flip_vertical_png_coordinates(x_gauge, png)

        end
        return if @def_y == 0.0

        y_gauge = Edge2D.new(Point2D.new(0.0, 0.0), Point2D.new(0.0, @def_y)).transform!(t)
        green = ChunkyPNG::Color.rgba(4, 170, 0, 128)

        # white antialiased outline on gauge endpoints
        flip_vertical_png_coordinates(y_gauge, png)
        png.circle_float(y_gauge.p2, 3, point_outline_color, outline_feather) # Y upper white antialiased outline
        flip_vertical_png_coordinates(y_gauge, png)

        draw_an_edge_or_line(y_gauge, penwidth_pixels, png, green)

        # black dots overdraw
        flip_vertical_png_coordinates(y_gauge, png)
        png.circle_float(y_gauge.p1, rad, dot_color, 1.1) # Y origin black dot overdraw
        png.circle_float(y_gauge.p2, rad, dot_color, 1.1) # Y upper black dot overdraw
        flip_vertical_png_coordinates(y_gauge, png)
      end

      def draw_cross_pattern(png, pen_width)
        # Draw a simple X across the canvas for preview
        edge1 = Edge2D.new(Point2D.new(0, 0), Point2D.new(png.width, png.height))
        edge2 = Edge2D.new(Point2D.new(0, png.height), Point2D.new(png.width, 0))

        draw_an_edge_or_line(edge1, pen_width, png)
        draw_an_edge_or_line(edge2, pen_width, png)
      end

      def draw_insulation_pattern(png, pen_width, style)
        # Draw a representative zigzag or S-curve for preview
        points = []
        steps = 20
        h = png.height * 0.4
        cy = png.height / 2.0

        if style == "scurve"
          (0..steps).each do |i|
            x = (i.to_f / steps) * png.width
            y = cy + (Math.sin((i.to_f / steps) * 4 * Math::PI) * h)
            points << Point2D.new(x, y)
          end
        else # zigzag
          (0..steps).each do |i|
            x = (i.to_f / steps) * png.width
            y = i.even? ? cy - h : cy + h
            points << Point2D.new(x, y)
          end
        end

        (0...points.size - 1).each do |i|
          draw_an_edge_or_line(Edge2D.new(points[i], points[i + 1]), pen_width, png)
        end
      end

      private :draw_gauges

      def draw_section_cut(png, pen_width)
        return if pen_width <= 0.0

        stroke_color = @opts[:section_line_color] || ChunkyPNG::Color::BLACK
        section_cut_edges = [
          Edge2D.new(Point2D.new(-pen_width / 2.0, 1 + (pen_width / 2.0)), Point2D.new(@hatchtile.width + (pen_width / 2.0), 1 + (pen_width / 2.0))), # bottom
          Edge2D.new(Point2D.new(-pen_width / 2.0, @hatchtile.height - (pen_width / 2.0)), Point2D.new(@hatchtile.width + (pen_width / 2.0), @hatchtile.height - (pen_width / 2.0))), # top
          Edge2D.new(Point2D.new(pen_width / 2.0, -pen_width / 2.0), Point2D.new(pen_width / 2.0, @hatchtile.height + pen_width)), # left
          Edge2D.new(Point2D.new(@hatchtile.width - (pen_width / 2.0) - 1, -pen_width / 2.0), Point2D.new(@hatchtile.width - (pen_width / 2.0) - 1, @hatchtile.height + pen_width)) # right
        ]

        section_cut_edges.each do |testedge|
          draw_an_edge_or_line(testedge, pen_width, png, stroke_color)
        end
      end

      private :draw_section_cut

      def parse_colors
        @opts[:line_color] = color_from_string(@opts[:line_color])
        @opts[:fill_color] = color_from_string(@opts[:fill_color])
        @opts[:section_line_color] = color_from_string(@opts[:section_line_color])
      end

      def color_from_string(str)
        return ChunkyPNG::Color::TRANSPARENT if str.nil? || str.empty?
        return ChunkyPNG::Color.from_hex(str) if str.start_with?("#")

        # Parse rgb(r, g, b) or rgba(r, g, b, a)
        values = str.scan(/(\d+(?:\.\d+)?|\.\d+)/).flatten.map(&:to_f)
        case values.size
        when 3
          ChunkyPNG::Color.rgb(values[0].to_i, values[1].to_i, values[2].to_i)
        when 4
          # alpha in rgba(...) is usually 0.0 to 1.0, but ChunkyPNG expects 0 to 255
          alpha = values[3] <= 1.0 ? (values[3] * 255).round : values[3].round
          ChunkyPNG::Color.rgba(values[0].to_i, values[1].to_i, values[2].to_i, alpha.to_i)
        else
          ChunkyPNG::Color::BLACK
        end
      rescue StandardError
        ChunkyPNG::Color::BLACK
      end

      private :parse_colors

      def save_png(png, name)
        png_constraints = { best_compression: true, interlace: false }
        return png.save(@opts[:output_path], png_constraints) if @opts[:output_path]
        if SkalpHatch.develop
          return png.save(File.expand_path("~") + "/Desktop/hatchtextures/#{@opts[:type]}_#{name}.png", png_constraints)
        end # external run

        png.save(Skalp::IMAGE_PATH + "#{@opts[:type]}.png", png_constraints)
      end

      private :save_png

      def to_base64_blob(png)
        png_constraints = { best_compression: true, interlace: false }
        Base64.encode64(png.to_blob({ best_compression: true, interlace: false })).gsub!("\n", "")
      end
      private :to_base64_blob

      def repeat_points(point, pointline, pen_width, png, hl, scale)
        t1 = Transformation2D.new.translation(hl.line_style_length_vector.x * scale,
                                              hl.line_style_length_vector.y * scale)
        t2 = t1.dup.inverse

        inside_hatchtile_edge = @hatchtile.intersect(pointline)
        return if inside_hatchtile_edge.class == Point2D

        t1, t2 = t2, t1 if direction(point, inside_hatchtile_edge, t1) == -1

        newpoint = point.dup
        started = false
        check = 0

        until started
          if inside_hatchtile_edge.point_on_edge?(newpoint)
            started = true
            draw_a_point(newpoint, pen_width, png)
            newpoint1 = newpoint.dup.transform!(t1)

            while inside_hatchtile_edge.point_on_edge?(newpoint1)
              draw_a_point(newpoint1, pen_width, png)
              newpoint1.transform!(t1)
            end
            newpoint2 = newpoint.dup.transform!(t2)

            while inside_hatchtile_edge.point_on_edge?(newpoint2)
              draw_a_point(newpoint2, pen_width, png)
              newpoint2.transform!(t2)
            end
          elsif inside_hatchtile_edge.position_on_edge?(newpoint) < 0
            return if check == 1

            check = -1
            newpoint.transform!(t1)
          elsif inside_hatchtile_edge.position_on_edge?(newpoint) > 1
            return if check == -1

            check = 1
            newpoint.transform!(t2)
          end
        end
      end

      private :repeat_points

      def repeat_dashes(dash, pen_width, png, hl, scale)
        t1 = Transformation2D.new.translation(hl.line_style_length_vector.x * scale,
                                              hl.line_style_length_vector.y * scale)
        t2 = t1.dup.inverse
        inside_hatchtile_edge = @hatchtile.intersect(dash)

        if inside_hatchtile_edge.class == Point2D # a Hatchtile cornerpoint
          cornerpoint = inside_hatchtile_edge
          t3 = Transformation2D.new.translation(cornerpoint.x, cornerpoint.y)
          helper_edge = Edge2D.new(Point2D.new(0.0, 0.0),
                                   Point2D.new(hl.line_style_length_vector.x * scale,
                                               hl.line_style_length_vector.y * scale)).transform!(t3)

          t1, t2 = t2, t1 if direction(dash.p1, helper_edge, t1) == -1

          newdash = dash.dup

          var = newdash.position_on_edge?(cornerpoint)
          case
          when 0.0 <= var && var <= 1.0
            draw_an_edge_or_line(newdash, pen_width, png)
            return if 0.0 <= var && var <= 1.0
          when var < 0.0
            t = t2
          when var > 1.0
            t = t1
          else
          end

          oldvalue = newdash.position_on_edge?(cornerpoint)
          newdash.transform!(t)
          newvalue = newdash.position_on_edge?(cornerpoint)

          until oldvalue * newvalue < 0
            if (0..1).include?(newvalue)
              draw_an_edge_or_line(newdash, pen_width, png)
              return
            end
            oldvalue = newdash.position_on_edge?(cornerpoint)
            newdash.transform!(t)
            newvalue = newdash.position_on_edge?(cornerpoint)
          end
          # elsif inside_hatchtile_edge.nil?
          #  return
        else
          t1, t2 = t2, t1 if direction(dash.p1, inside_hatchtile_edge, t1) == -1

          newdash = dash.dup
          started = false

          until started
            param1 = inside_hatchtile_edge.position_on_edge?(newdash.p1)
            param2 = inside_hatchtile_edge.position_on_edge?(newdash.p2)

            if (param1 < 0 && param2 > 1) || (param2 < 0 && param1 > 1)
              draw_an_edge_or_line(inside_hatchtile_edge, pen_width, png)
              started = true
            elsif inside_hatchtile_edge.point_on_edge?(newdash.p1) || inside_hatchtile_edge.point_on_edge?(newdash.p2)
              started = true
              draw_an_edge_or_line(newdash, pen_width, png)
              newdash1 = newdash.dup.transform!(t1)

              while inside_hatchtile_edge.point_on_edge?(newdash1.p1) || inside_hatchtile_edge.point_on_edge?(newdash1.p2)
                draw_an_edge_or_line(newdash1, pen_width, png)
                newdash1.transform!(t1)
              end

              newdash2 = newdash.dup.transform!(t2)

              while inside_hatchtile_edge.point_on_edge?(newdash2.p1) || inside_hatchtile_edge.point_on_edge?(newdash2.p2)
                draw_an_edge_or_line(newdash2, pen_width, png)
                newdash2.transform!(t2)
              end
            elsif param1 < 0 && param2 < 0
              newdash.transform!(t1)
              if inside_hatchtile_edge.position_on_edge?(newdash.p1) > 1 && inside_hatchtile_edge.position_on_edge?(newdash.p2) > 1
                return
              end

            elsif param1 > 1 && param2 > 1
              newdash.transform!(t2)
              if inside_hatchtile_edge.position_on_edge?(newdash.p1) < 0 && inside_hatchtile_edge.position_on_edge?(newdash.p2) < 0
                return
              end
            end
          end
        end
      end

      private :repeat_dashes

      # object can be  Edge2D || Line2D
      def draw_an_edge_or_line(object, pen, png, stroke_color = @opts[:line_color])
        object = object.dup.transform!(@comp_trans) unless %i[preview thumbnail].include?(@opts[:type])
        edge = object.dup
        flip_vertical_png_coordinates(edge, png)

        return draw_one_pixel_line(png, edge, stroke_color) if pen <= 1.0 && @opts[:type] == :tile

        p0 = edge.p1
        p1 = edge.p2
        draw_pen_line(p0, p1, pen, png, stroke_color, strokevector(p0, p1, pen))
      end

      private :draw_an_edge_or_line

      def flip_vertical_png_coordinates(edge, png)
        edge.p1.y = png.height - edge.p1.y
        edge.p2.y = png.height - edge.p2.y
      end

      private :flip_vertical_png_coordinates

      def draw_a_point(object, pen, png, stroke_color = @opts[:line_color])
        object = object.dup.transform!(@comp_trans) unless %i[preview thumbnail].include?(@opts[:type])
        point = object.dup
        point.y = png.height - point.y # flip vertical png coordinates
        png.circle_float(point, pen / 2, stroke_color = @opts[:line_color], 1.1)
      end

      private :draw_a_point

      def strokevector(p0, p1, pen)
        angle = SkalpHatch.lineangle(p0, p1)
        dx = Math.cos(angle) * pen / 2
        dy = Math.sin(angle) * pen / 2
        return if [p0.x, p0.y, p1.x, p1.y, pen, dx, dy].any? { |v| v.nan? || v.infinite? }

        p0_left = Point2D.new(p0.x - dx, p0.y + dy)
        p0_right = Point2D.new(p0.x + dx, p0.y - dy)
        p1_left = Point2D.new(p1.x - dx, p1.y + dy)
        p1_right = Point2D.new(p1.x + dx, p1.y - dy)

        ChunkyPNG::Vector(p0_left, p0_right, p1_right, p1_left)
      end

      private :strokevector

      def draw_one_pixel_line(png, edge, stroke_color = @opts[:line_color])
        png.line_float(edge.p1.x, edge.p1.y, edge.p2.x, edge.p2.y, stroke_color, inclusive = true)
      end

      private :draw_one_pixel_line

      def draw_pen_line(p0, p1, pen, png, stroke_color, v0)
        return if p0.x.nan? || p0.y.nan? || p1.x.nan? || p1.y.nan? || v0.nil?

        png.polygon(v0, stroke_color, fill_color = stroke_color)
        png.circle_float(p0, pen / 2, stroke_color, 1.1)
        png.circle_float(p1, pen / 2, stroke_color, 1.1)
      end

      private :draw_pen_line

      def direction(point, edge, t)
        case edge
        when Edge2D
          edge.position_on_edge?(point) < edge.position_on_edge?(point.dup.transform!(t)) ? 1 : -1
        when Point2D
          0
        end
      end

      private :direction

      # Helper method to ensure a number is valid (not NaN, not Infinity)
      # Returns the fallback value if the input is invalid
      def safe_number(value, fallback = 0.0)
        return fallback if value.nil?
        return fallback unless value.respond_to?(:nan?) && value.respond_to?(:infinite?)
        return fallback if value.nan? || value.infinite?
        return fallback if value.abs < 1e-10 # Treat very small numbers as zero

        value
      end

      private :safe_number
    end # class Hatch
  end
end
