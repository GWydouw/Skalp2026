module Skalp
  require "Skalp_Skalp2026/Skalp_lib2"
  Dir.chdir(SU_USER_PATH)

  # SECTION OFFSET DISTANCE

  def self.tolerance
    Sketchup.read_default("Skalp", "tolerance2").to_f
  end

  def self.set_tranformation_down
    @transformation_down = Geom::Transformation.translation Geom::Vector3d.new(0, 0, -1 * tolerance)
  end

  def self.set_section_offset
    # remark: 7 extra 'space' characters needed after first string to avoid UI dialog visibility clipping bug.
    Skalp.inputbox_custom(["#{Skalp.translate('Section Offset Distance:')}       "],
                          [Sketchup.format_length(Sketchup.read_default("Skalp", "tolerance2").to_f)], "Skalp #{Skalp.translate('Preference')}") do |input|
      next unless input

      measure = input[0].gsub(" ", "")
      measure_string = correct_decimal(measure.to_s)

      Sketchup.write_default("Skalp", "tolerance2", Skalp.to_inch(measure_string).to_s)
      set_tranformation_down
      if Skalp.active_model && Skalp.active_model.active_sectionplane
        Skalp.active_model.active_sectionplane.calculate_section
      end
    end
  end

  Sketchup.write_default("Skalp", "tolerance2", "0.0394") unless Sketchup.read_default("Skalp", "tolerance2")

  set_tranformation_down

  # DRAWING SCALE
  def self.default_drawing_scale
    Sketchup.read_default("Skalp", "drawing_scale").to_f
  end

  def self.set_default_drawing_scale(scale = nil)
    if scale
      scale_val = scale.to_s
      scale_val = 50.0.to_s if scale_val.to_f == 0.0
      Sketchup.write_default("Skalp", "drawing_scale", scale_val)
    else
      Skalp.inputbox_custom(["#{Skalp.translate('Set Default Drawing Scale')} 1:"],
                            [Sketchup.read_default("Skalp", "drawing_scale").to_s], "Skalp") do |input|
        next unless input

        scale = input[0].to_s
        scale = 50.0.to_s if scale.to_f == 0.0
        Sketchup.write_default("Skalp", "drawing_scale", scale)
      end
    end
  end

  Sketchup.write_default("Skalp", "drawing_scale", "50") unless Sketchup.read_default("Skalp", "drawing_scale")
end
