module Skalp
  module LayerColorManager
    require 'json'
    extend self

    ORIGINAL_COLORS_KEY = 'original_layer_colors'
    WHITE_MODE_KEY = 'white_mode_active'

    def check_white_mode_active
      Sketchup.active_model.get_attribute('LayerColorManager', WHITE_MODE_KEY, true)
    end

    # Change all layers' colors to white and store original colors
    def set_layers_to_white
      model = Sketchup.active_model

      layers = model.layers

      # Start operation for undo
      Skalp.active_model.start('Skalp - Set Tag Colors to White', true)

      # Retrieve existing original colors or initialize
      original_colors_string = model.get_attribute('LayerColorManager', ORIGINAL_COLORS_KEY, '{}')
      original_colors = JSON.parse(original_colors_string) rescue {}

      # Update stored colors and set layers to white
      layers.each do |layer|
        unless original_colors.key?(layer.name)
          original_colors[layer.name] = {
            "r" => layer.color.red,
            "g" => layer.color.green,
            "b" => layer.color.blue
          }
        end

        # Change the layer's color to white
        layer.color = Sketchup::Color.new(255, 255, 255)
      end

      # Save updated original colors as a JSON string to model attributes
      model.set_attribute('LayerColorManager', ORIGINAL_COLORS_KEY, original_colors.to_json)
      model.set_attribute('LayerColorManager', WHITE_MODE_KEY, true)

      Skalp.active_model.commit
    end

    # Revert all layers to their original colors
    def revert_layer_colors
      model = Sketchup.active_model

      # Check if we are in white mode
      unless model.get_attribute('LayerColorManager', WHITE_MODE_KEY, false)
        return
      end

      layers = model.layers

      # Start operation for undo
      Skalp.active_model.start('Skalp - Revert Tag Colors', true)

      # Retrieve original colors from model attributes
      original_colors_string = model.get_attribute('LayerColorManager', ORIGINAL_COLORS_KEY, '{}')
      original_colors = JSON.parse(original_colors_string) rescue {}

      if original_colors.empty?
        model.commit_operation
        return
      end

      layers.each do |layer|
        if original_colors.key?(layer.name)
          original_color = original_colors[layer.name]
          if original_color.is_a?(Hash) && original_color.key?('r') && original_color.key?('g') && original_color.key?('b')
            layer.color = Sketchup::Color.new(original_color['r'], original_color['g'], original_color['b'])
          end
        end
      end

      # Reset white mode flag
      model.set_attribute('LayerColorManager', WHITE_MODE_KEY, false)

      Skalp.active_model.commit
    end

  end
end
# Add methods to the Extensions menu for easy access
unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins').add_submenu('Skalp - Tag Color Manager')
  menu.add_item('Set All Tag Colors to White') { Skalp::LayerColorManager.set_layers_to_white }
  menu.add_item('Revert Original Tag Colors') { Skalp::LayerColorManager.revert_layer_colors }
  file_loaded(__FILE__)
end
