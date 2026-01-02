require 'sketchup'
require 'extensions'

# Mock Skalp environment if needed, or load it
# Assuming Skalp is already loaded in the environment or we can load it.

def benchmark_create_png
  puts "Starting Benchmark..."
  t_start = Time.now
  
  # Create a dummy hatch definition if possible or use existing
  # This is tricky without the full context, so we might need to rely on existing objects.
  
  # Let's try to access the Skalp::Hatch_dialog instance if it exists
  # Or instantiate a new Hatch object.
  
  hatch = Skalp::SkalpHatch::Hatch.new
  # We need a hatch definition.
  # Let's see if we can load one.
  # For now, let's just create a SOLID_COLOR one as it's simplest
  hatch.add_hatchdefinition(Skalp::SkalpHatch::HatchDefinition.new(["SOLID_COLOR, solid color without hatching", "45, 0,0, 0,.125"]))
  
  10.times do
    hatch.create_png({
      type: :preview,
      width: 215,
      height: 100,
      line_color: "rgb(0,0,0)",
      fill_color: "rgb(255,0,0)",
      section_line_color: "rgb(0,0,0)",
      section_cut_width: 0.05,
      pen: 0.01
    })
  end
  
  t_end = Time.now
  puts "Benchmark finished. Total time for 10 iterations: #{t_end - t_start} seconds."
  puts "Average time per iteration: #{(t_end - t_start) / 10.0} seconds."
end

benchmark_create_png
