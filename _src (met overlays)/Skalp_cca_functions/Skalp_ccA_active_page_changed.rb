  def ccA(page)
    return unless page && page.class == Sketchup::Page
    return if page.deleted?
    return unless @model.skpModel.pages
    return unless @model.skpModel.pages.include?(page)

    if @model
      unless @model.undoredo_action
        if @model.pages[page] && (page.name != @model.pages[page].name)
          @model.pages[page].name = page.name
        end

        page_active_sectionplaneID = @model.get_memory_attribute(page, 'Skalp', 'sectionplaneID')
        page_active_sectioplane_by_id = @model.sectionplane_by_id(page_active_sectionplaneID)  if page_active_sectionplaneID
        page_active_section = Sketchup.active_model.entities.active_section_plane

        if page_active_section && page_active_section.get_attribute('Skalp', 'ID') && !@model.get_memory_attribute(page, 'Skalp', 'ID')
          Skalp::Page.new(page, true, true)
        end

        if @model.active_page == @model.skpModel.pages.selected_page   #page updated by user

          if (page_active_section && page_active_section.get_attribute('Skalp', 'ID') && !page_active_sectionplaneID) ||
              (page_active_sectioplane_by_id != page_active_section)

            unless Skalp.active_model.dialog_undo_flag
              data = {
                  :action => :update_skalp_scene,
              }
              Skalp.active_model.controlCenter.add_to_queue(data)
            end
          end
        else #page switch
          @model.active_page = @model.skpModel.pages.selected_page
          Skalp.page_change = true

          @model.start("Skalp - #{Skalp.translate('change scene')}", true)
          Skalp.dialog.update_styles(page) if Skalp.dialog
          sectionplaneID = @model.get_memory_attribute(page, 'Skalp', 'sectionplaneID')
          active_sectionplane = Sketchup.active_model.entities.active_section_plane

          if active_sectionplane
            active_sectionplaneID = active_sectionplane.get_attribute('Skalp', 'ID')
            Skalp.active_model.set_memory_attribute(page, 'Skalp', 'sectionplaneID', active_sectionplaneID) if sectionplaneID != active_sectionplaneID
          else
            Skalp.active_model.set_memory_attribute(page, 'Skalp', 'sectionplaneID', nil)
          end

          @model.hidden_entities_by_page(page)
          if sectionplaneID
            if @model.sectionplane_by_id(sectionplaneID)
              Skalp.sectionplane_active = true
              Skalp.dialog.show_dialog_settings

              if sectionplaneID != active_sectionplaneID
                Skalp::update_page(page)
                @update_needed = false

                skalp_sectionplane =  @model.sectionplane_by_id(active_sectionplaneID)

                if active_sectionplane && skalp_sectionplane
                  active_sectionplane_name = skalp_sectionplane.name
                else
                  active_sectionplane_name = "- #{NO_ACTIVE_SECTION_PLANE} -"
                end
                @model.hiddenlines.set_active_page_hiddenlines_to_model_hiddenlines
                Skalp.change_active_sectionplane(active_sectionplane_name)
                Skalp.dialog.script("$('#sections_list').val('#{active_sectionplane_name}')")

                @page_switch = true
                @update_needed = false
              else
                @page_switch = true
              end

              Sketchup.active_model.styles.selected_style = Sketchup.active_model.styles.selected_style if Sketchup.active_model.styles.selected_style
            else
              Skalp.dialog.blur_dialog_settings
              page_id = @model.get_memory_attribute(page, 'Skalp', 'ID')
              @model.delete_memory_attribute(page, "Skalp")
              layer = Skalp.active_model.layer_by_id(sectionplaneID)
              layer.delete  if layer && layer.skpLayer.valid?

              to_delete = []
              @skpModel.entities.grep(Sketchup::Group).each do |group|
                next if group.deleted?
                if group.get_attribute('Skalp', 'ID') == page_id
                  group.locked = false
                  to_delete << group
                end
              end
              @skpModel.entities.erase_entities(to_delete)
            end
          else
            Skalp.dialog.no_active_sectionplane(page)
          end
          @undo_page_switch = true
          Skalp.page_change = false
          @model.set_memory_attribute(@skpModel, 'Skalp', 'selected_page', page)
          @model.commit
        end
      end
    end
  rescue => e
      Skalp.errors(e)
  end
