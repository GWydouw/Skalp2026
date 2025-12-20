# Skalp Patterns - plugin for SketchUp.
#
# Creates tilable png textures for use in SketchUp and Layout. Imports pattern definitions
# from standard ACAD.PAT pattern files.
#
# @author Skalp (C) 2014

module Skalp
  module SkalpHatch
    # Basic requirements from standard library

    class << self
      attr_accessor :fill_color, :clipsize, :hatches, :hatchdefs, :user_input
      attr_reader :develop
    end
    @fill_color = ChunkyPNG::Color::BLACK # TRANSPARENT #BLACK
    @clipsize = 2048 # maximum png width / height in pixels (should be 2048)  #TODO avoid tile_factor infinite loop for certain patterns
    @develop = true unless defined?(Sketchup) # set true to run outside SketchUp

    # MAIN
    def self.load_hatch
      @hatchdefs = []
      @hatchdef = nil
      if @develop
        pat_path = File.join(File.dirname(__FILE__), 'resources/hatchdevelop')
        outputpath = File.expand_path('~') + '/Desktop/hatchtextures/'
        FileUtils.rm_rf Dir.glob("#{outputpath}/*")
      else
        pat_path = Sketchup.find_support_file('Plugins') + '/Skalp_Skalp/resources/hatchpats'
      end

      matlist = Dir.glob("#{pat_path}/**/*.{pat,PAT}")
      matlist.each { |filepath| import_pat_file(filepath) }
    end

    def self.test_tiling
      load_hatch
      puts 'RUN THIS OUTSIDE SU ONLY'
      @hatches ||= []

      @hatchdefs.each do |hatchdef|
        hatch = Hatch.new
        hatch.add_hatchdefinition(hatchdef)
        @hatches << hatch
      end
      # Skalp.default_hatch = @hatches[0]
      @hatches.each do |hatch|
        puts hatch.hatchdefinition.name
        retval = hatch.create_png(type: :preview,
                                  gauge: true,
                                  width: 237, # width       140    #incon preview: 70 x 35, drawing factor 80
                                  height: 100, # heigth      100
                                  line_color: 'rgb(0, 0, 0)',
                                  fill_color: 'rgba(255, 255, 255, 1.0)',
                                  pen: 3.0 / 72, # pen_width in inch (1pt = 1.0 / 72)1.0 / 72       #(300.0/72) * 0.51 / 72

                                  resolution: 72,
                                  print_scale: 50, # e.g. 1, 10, 20, 50, 100, 500, 1000 for metric, 1, 12, 24, 48, 96 for imperial
                                  zoom_factor: 0.5,
                                  space: :paperspace)

        puts retval[:gauge_ratio]

        #=begin
        retval = hatch.create_png(type: :tile,
                                  line_color: 'rgb(0, 0, 0)',
                                  fill_color: 'rgba(255, 255, 255, 1.0)',
                                  pen: 1.0 / 72, # pen_width in inch (1pt = 1.0 / 72)1.0 / 72       #(300.0/72) * 0.51 / 72

                                  resolution: 300,
                                  print_scale: 50, # e.g. 1, 10, 20, 50, 100, 500, 1000 for metric, 1, 12, 24, 48, 96 for imperial
                                  user_x: 0.5, # [0..(width/res)] inch for paperspace,   [0*print_scale..(width/res)*print_scale] for modelspace
                                  space: :paperspace)
        #:space          => :modelspace)
        #=end
        # puts retval[:original_definition] , retval[:gauge_ratio]
      end
    end

    def self.round_to(num, x)
      (num * 10**x).round.to_f / 10**x
    end

    def self.radians(degrees)
      degrees * Math::PI / 180
    end

    def self.degrees(radians)
      radians * 180 / Math::PI
    end

    def self.lineangle(p0, p1)
      Math.atan2(p0.x - p1.x, p0.y - p1.y)
    end

    def self.import_pat_file(filepath)
      pattern_string = nil
      options = ['r', 'r:iso-8859-1:utf-8'] # http://nuclearsquid.com/writings/ruby-1-9-encodings/ read as iso-8859-1 externaly, transcode to utf-8 internally

      options.each do |opts|
        begin
          File.open(filepath, opts).read.split(/\r\n|\r|\n/).each do |line|
            if line =~ /EXIT/i # this is a temporary hack, real ACAD.PAT files tend to end with a bunch of spaces, grr
              HatchDefinition.new(pattern_string) if pattern_string
              pattern_string = nil
              break
            end

            next if line !~ /\w/ || line =~ /;/

            if line[0..0] == '*'
              HatchDefinition.new(pattern_string) if pattern_string
              pattern_string = []
              pattern_string << line
            else
              pattern_string << line
            end
          end
          break
        rescue ArgumentError
        end
      end

      HatchDefinition.new(pattern_string) if pattern_string
    end

    @develop && test_tiling
  end # module SkalpHatch
end
