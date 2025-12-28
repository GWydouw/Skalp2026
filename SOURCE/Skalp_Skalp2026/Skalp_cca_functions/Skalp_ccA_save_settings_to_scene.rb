def ccA()
  unless @model.undoredo_action
    if @skpModel && @skpModel.pages
      active_page = @skpModel.pages.selected_page
      if active_page
        @model.start(Skalp.translate('Skalp - update scene'), true)
        if @model.get_memory_attribute(active_page, 'Skalp','ID') && @model.active_sectionplane
          @model.set_memory_attribute(active_page, 'Skalp','sectionplaneID', @model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID'))

          Skalp::update_page(active_page)
          @model.active_sectionplane.section.manage_sections(active_page)

        elsif @model.get_memory_attribute(active_page, 'Skalp','ID') && !@model.active_sectionplane
          id = @model.get_memory_attribute(active_page, 'Skalp','ID')
          @model.delete_memory_attribute(active_page, 'Skalp')
          Skalp::update_page(active_page)

          @model.skalp_pages_LUT.delete(active_page)
          layer = @model.layer_by_id(id)

          layer.delete if layer && layer.skpLayer.valid?

          for layer in @skpModel.layers
            if layer.get_attribute('Skalp','ID')
              active_page.set_visibility(layer, false)
            end
          end
        elsif !@model.get_memory_attribute(active_page, 'Skalp','ID') && @model.active_sectionplane
          @model.set_memory_attribute(active_page, 'Skalp','sectionplaneID', @model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID'))
          Skalp::update_page(active_page)
          Page.new(active_page, true)
          @model.active_sectionplane.section.section_to_sectiongroup(@model.active_sectionplane.section.create_sectiongroup(active_page))
          @model.active_sectionplane.section.manage_sections(active_page)
        end

        @model.commit
      end
    end
  end

rescue => e
  Skalp.errors(e)
end
