module Skalp
  module Converter

    def self.convert_section_materials(entities)
      for e in entities
        material = e.get_attribute('ArribaSection', 'sectionmaterial')
        if material
          new_material = material.to_s
          e.set_attribute('Skalp', 'sectionmaterial', new_material)
          e.delete_attribute('ArribaSection')
        end

        e.is_a?(Sketchup::Group) && convert_section_materials(e.entities)
        e.is_a?(Sketchup::ComponentInstance) && convert_section_materials(e.definition.entities)
      end
    end

    def self.convert_active_model
      Sketchup.active_model.start_operation 'fixmodel', true

      puts 'section materials'
      self.convert_section_materials(Sketchup.active_model.entities)

      puts 'materials'
      self.convert_materials

      puts 'hatch by layer'
      self.convert_hatch_by_layer_layers

      puts 'sectionplanes and pages'
      self.convert_sectionplanes_and_pages

      puts 'delete old layers'
      #self.delete_old_layers

      puts 'delete old sectiongroups'
      self.delete_old_section_groups

      Sketchup.active_model.commit_operation
    end

    def self.delete_old_layers
      layers_to_delete = []
      for layer in Sketchup.active_model.layers
        layers_to_delete << layer if layer.get_attribute('ArribaSection', 'ID')
        layers_to_delete << layer if layer.name == 'SECTION normal'
        layers_to_delete << layer if layer.name == 'SECTION reverse'
      end

      layers_to_delete.each { |layer| layer.delete(true) }
    end

    def self.delete_old_section_groups
      entities_to_delete = []
      for entity in Sketchup.active_model.entities
        if entity.is_a?(Sketchup::Group)
          entities_to_delete << entity if entity.get_attribute('ArribaSection', 'ID')
        end
      end

      Sketchup.active_model.entities.erase_entities(entities_to_delete)
    end

    def self.convert_sectionplanes_and_pages
      for sectionplane in Sketchup.active_model.entities.grep(Sketchup::SectionPlane)
        if sectionplane.get_attribute('ArribaSection', 'ID')
          sectionplaneID = self.ripArriba(sectionplane.get_attribute('ArribaSection', 'ID'))
          sectionplane_name = sectionplane.get_attribute('ArribaSection', 'sectionplane_name')
          sectionplane.set_attribute('Skalp', 'ID', sectionplaneID)
          sectionplane.set_attribute('Skalp', 'sectionplane_name', sectionplane_name)

          #zoek page en link met page
          for page in Sketchup.active_model.pages
            next unless page.get_attribute('ArribaSection', 'sectionplaneID')
            if self.ripArriba(page.get_attribute('ArribaSection', 'sectionplaneID')) == sectionplaneID
              page.set_attribute('Skalp', 'sectionplaneID', sectionplaneID)
              page.delete_attribute('ArribaSection')
            end
          end

          #zoek sectionplane layer en link met layer
          for layer in Sketchup.active_model.layers
            next unless layer.get_attribute('ArribaSection', 'ID')

            if self.ripArriba(layer.get_attribute('ArribaSection', 'ID')) == sectionplaneID
              layer.name = "SectionPlane: #{sectionplane_name}"
              layer.set_attribute('Skalp', 'ID', sectionplaneID)
              layer.delete_attribute('ArribaSection')
            end
          end

          #verwijder oude meta data
          sectionplane.delete_attribute('ArribaSection')
        end
      end
    end

    def self.convert_hatch_by_layer_layers
      for layer in Sketchup.active_model.layers
        if layer.name.include?('¡Arriba hatch by layer') then
          layer.name = self.ripArriba(layer.name).gsub('Arriba', 'Skalp')
        end
      end
    end

    def self.convert_materials
      for material in Sketchup.active_model.materials
        material.name = self.ripArriba(material.name)
      end
    end

    def self.ripArriba(string)
      string.gsub('!', '').gsub('¡', '')
    end

  end
end
