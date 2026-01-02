$LOAD_PATH << File.expand_path('../SOURCE', File.dirname(__FILE__))
require 'Skalp_Skalp2026/chunky_png/lib/chunky_png'
require 'matrix'
# Mock Skalp module if strictly necessary for constants, but Hatch is namespaced
module Skalp; end
require 'Skalp_Skalp2026/Skalp_geom2' # Likely needed for Point2D etc
require 'Skalp_Skalp2026/Skalp_hatch_lib'
require 'Skalp_Skalp2026/Skalp_hatch_class'
require 'Skalp_Skalp2026/Skalp_hatchdefinition_class'
require 'Skalp_Skalp2026/Skalp_hatchline_class'
require 'Skalp_Skalp2026/Skalp_hatchtile'

# Mock Skalp.translate as it's used in hatch class (maybe?)
def Skalp.translate(str); str; end
# Mock SkalpHatch.develop and hatchdefs
module Skalp::SkalpHatch
  def self.develop; false; end
  def self.hatchdefs; @hatchdefs ||= []; end
  def self.radians(deg); deg * Math::PI / 180.0; end
  def self.user_input=(val); @user_input = val; end
  def self.user_input; @user_input; end
  def self.lineangle(a, b=nil)
    if b
      Math.atan2(b.y - a.y, b.x - a.x)
    else
      Math.atan2(a.p2.y - a.p1.y, a.p2.x - a.p1.x)
    end
  end
end
# Mock constants
PRINT_DPI = 300 unless defined?(PRINT_DPI)

begin
  puts "Verifying Section Line Color..."

  # 1. Instantiate Pattern Info with section_line_color
  pattern_info_red = {
      pattern: ["ANSI31"],
      print_scale: 1,
      resolution: 300,
      user_x: "0",
      space: :modelspace,
      pen: "0.18 mm",
      section_cut_width: 0.013, 
      line_color: "rgb(0,0,0)",
      fill_color: "rgb(255,255,255)",
      section_line_color: "rgb(255,0,0)" # RED
  }
  
  pattern_info_black = pattern_info_red.merge({ section_line_color: "rgb(0,0,0)" }) # BLACK

  # 2. Generate Thumbnails (blobs) using Skalp::Hatch
  # We can access Skalp::SkalpHatch::Hatch directly
  hatch = Skalp::SkalpHatch::Hatch.new
  hatch.add_hatchdefinition(Skalp::SkalpHatch::HatchDefinition.new(["ANSI31", "45, 0, 0, 0, .125"]))
  
  # create_png arguments mapping from pattern_info
  # We need to simulate arguments passed to create_png in Skalp_hatch_dialog.rb create_preview/create_hatch
  # create_png(opts)
  
  opts_red = {
    solid_color: false,
    type: :preview, 
    line_color: pattern_info_red[:line_color],
    fill_color: pattern_info_red[:fill_color],
    pen: 0.007, # approx 0.18mm
    section_cut_width: 0.013,
    resolution: 300,
    print_scale: 1,
    zoom_factor: 1.0,
    user_x: 1.0,
    space: :modelspace,
    section_line_color: pattern_info_red[:section_line_color]
  }

  opts_black = opts_red.merge({ section_line_color: "rgb(0,0,0)" })

  puts "Generating Red PNG..."
  result_red = hatch.create_png(opts_red)
  
  puts "Generating Black PNG..."
  result_black = hatch.create_png(opts_black)
  
  blob_red = result_red[:png_base64]
  blob_black = result_black[:png_base64]
  
  if blob_red != blob_black
    puts "SUCCESS: Red and Black thumbnails are different."
    puts "Red Blob length: #{blob_red.length}"
    puts "Black Blob length: #{blob_black.length}"
  else
    puts "FAILURE: Red and Black thumbnails are identical. Section Line Color is ignored."
  end

rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace
end
