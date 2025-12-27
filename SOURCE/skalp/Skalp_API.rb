module Skalp
  module API
    def self.get_material_for_layer(layer)
      layer.get_attribute("Skalp", "material")
    end

    def self.set_material_for_layer(layer, material_name)
      layer.set_attribute("Skalp", "material", material_name)
    end

    def self.open_material_dialog(&callback)
      Material_dialog.external_callback = callback
      Material_dialog.show_dialog(100, 100)
    end
  end
end