# Skalp Patterns - plugin for SketchUp.
#
# Creates tilable png textures for use in SketchUp and Layout. Imports pattern definitions
# from standard ACAD.PAT pattern files.
#
# @author Skalp (C) 2014

module Skalp
  module SkalpHatch
    class HatchDefinition
      attr_accessor :name, :description, :hatchlines, :originaldefinition, :force_update, :print_scale, :pat_unit_to_inch,
                    :def_x, :def_y
      attr_reader :canvasxsize, :canvasysize, :definitionxbbox, :definitionybbox, :scale_normalisation, :original_ppi,
                  :ppi

      def initialize(pattern_string, save_to_hatchdefs = true)
        SkalpHatch.hatchdefs << self if SkalpHatch.hatchdefs && save_to_hatchdefs
        @originaldefinition = pattern_string.dup
        pattern_string = pattern_string.dup

        @print_scale = 50 # intended scale  SKP/LAYOUT > 1to1 / 1to50

        line = preprocesshatchline(pattern_string.shift)
        @name = line[0]
        @description = line[1]

        @hatchlines = []
        pattern_string.each do |line|
          next if line[0] == "*"

          processedline = Skalp::SkalpHatch::HatchLine.preprocesshatchline(line)
          if processedline.size >= 5
            add_hatchline(line, processedline)
          else
            # Silently skip empty/dummy lines (like [0.0] from procedural gens)
            # puts "Skipping pattern line: #{processedline} (argument size error)" unless processedline == ["0.0"]
          end
        end
      end

      def add_hatchline(hatchline, processedline)
        @hatchlines << HatchLine.new(self, hatchline, processedline) # TODO: REFACTOR: self niet meegeven, callers moeten super gebruiken
      end

      def dimensions
        tempxsizes ||= []
        tempysizes ||= []
        tempoffset ||= []
        for hl in @hatchlines
          sizes = hl.update_tiling_size(false)

          tempxsizes << sizes[0]
          tempysizes << sizes[1]
          tempoffset << hl.yoffset
        end
        tempxsizes = tempxsizes.uniq - [0.0]
        tempysizes = tempysizes.uniq - [0.0]
        tempoffset = tempoffset.uniq

        x_size = max_size(tempxsizes)
        y_size = max_size(tempysizes)
        @def_x = x_size == 0.0 ? y_size : x_size
        @def_y = y_size == 0.0 ? x_size : y_size

        offset_size = if tempoffset.size >= 2
                        tempoffset.inject(0) { |num1, num2| [num1, num2].max }
                      elsif tempoffset[0]
                        tempoffset[0].abs
                      else
                        0.0
                      end

        [@def_x, @def_y, offset_size]
      end

      def max_size(tempsizes)
        return 0.0 if tempsizes.nil? || tempsizes.empty?

        x_size = tempsizes.max
        return 0.0 unless x_size

        x_size.abs
      end

      def update_tile_size
        for hl in @hatchlines
          hl.update_tiling_size(true)
        end

        for hl in @hatchlines
          tempxbboxes ||= []
          tempybboxes ||= []
          tempxbboxes << hl.xbbox
          tempybboxes << hl.ybbox
        end

        tempxbboxes ||= []
        tempybboxes ||= []
        tempxbboxes = tempxbboxes.uniq - [0.0]
        tempybboxes = tempybboxes.uniq - [0.0]
        @definitionxbbox = if tempxbboxes.size >= 2
                             tempxbboxes.max # .inject(0) { |num1, num2| [num1, num2].max } #TODO use relevance here
                           elsif tempxbboxes[0].nil?
                             0.0
                           else
                             tempxbboxes[0].abs

                           end
        @definitionybbox = if tempybboxes.size >= 2
                             tempybboxes.max # .inject(0) { |num1, num2| [num1, num2].max } #TODO use relevance here
                           elsif tempybboxes[0].nil?
                             0.0
                           else
                             tempybboxes[0].abs

                           end
        # x hatchtile size 25% for pattern without xbbox
        @definitionxbbox = 0.25 * @definitionybbox if @definitionxbbox == 0.0
        # y hatchtile size 25% for pattern without ybbox
        @definitionybbox = 0.25 * @definitionxbbox if @definitionybbox == 0.0
      end

      def def_normalisation
        def_dims = dimensions # get max linestyle projections
        def_y = def_dims[1]
        def_offset = def_dims[2]
        compensation = 1.0
        if def_offset / def_y < 1.0 / 4.0 # use max def_offset to compensate for too large patterns TODO implement something smarter here.
          compensation = def_y / def_offset
        end
        @scale_normalisation = compensation
      end

      def ppi=(res)
        @original_ppi ||= res
        @ppi = res
      end

      def preprocesshatchline(linefromfile)
        if linefromfile.start_with?("*")
          linefromfile[1..-1].chomp.split(",", 2)
        else
          linefromfile.chomp.split(",", 2)
        end
      end

      # Attention: only to be used for DXF export. Do NOT try to create anything tilable from a rotated HatchDefinition instance, you will blow a fuse!
      def rotate!(radians)
        degrees = SkalpHatch.degrees(radians)
        @hatchlines.each do |hl|
          hl.rotate!(degrees) unless degrees == 0
        end
      end

      # Attention: only to be used for DXF export. Do NOT try to create anything tilable from a translated HatchDefinition instance, you will blow a fuse!
      def translate!(x, y)
        @hatchlines.each do |hl|
          hl.translate!(x, y)
        end
      end

      # Attention: only to be used for DXF export. Do NOT try to create anything tilable from a translated HatchDefinition instance, you will blow a fuse!
      def scale!(factor)
        @hatchlines.each do |hl|
          hl.scale!(factor)
        end
      end
    end # class HatchDefinition
  end
end
