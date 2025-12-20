def ccA(entity)
  return if entity.deleted?
  if entity.is_a?(Sketchup::SectionPlane)
    @add_sectionplane = true
    @add_sectionplane_finished = false
    timer_started = false
    timer_id = UI.start_timer(0.1, false) {

      if (entity.name && entity.name != '') && (entity.symbol && entity.symbol != '')
        unless timer_started #workaround bug sketchup on windows

          @model.start("Skalp - #{Skalp.translate('add new sectionplane')}", false)
          Skalp.dialog.webdialog.execute_script("$('#drawing_scale_title').show()")
          Skalp.dialog.webdialog.execute_script("$('#drawing_scale').show()")

          timer_started = true

          @model.set_sectionplane_layers_off
          @model.set_skalp_layers_off

          sectionplane_name = entity.get_attribute('Skalp', 'sectionplane_name')
          if sectionplane_name && @model.count_sectionplanes_by_name(sectionplane_name) == 1
            @model.add_sectionplane(entity, false) unless @model.undoredo_action
          else
            if sectionplane_name
              @model.start
              entity.delete_attribute('Skalp')
              @model.commit
              entity.activate
            end

            max = 0
            @model.sectionplanes.each_value {|value|
              next unless value
              name = value.sectionplane_name
              if name && name.include?('Section')
                name.include?('Section#') ? num = name.gsub('Section#', '').to_i : num = 1
                if num > max
                  max = num
                end
              end
            }

            max > 0 ? section_name = "#{Skalp.translate('Section')}##{max + 1}" : section_name = Skalp.translate('Section')
            default = Sketchup.read_default('Skalp', 'default_inputbox_create_scene') || Skalp.translate('Yes')
            result = UI.inputbox ['Create scene for section?'], [default], ["#{Skalp.translate('Yes')}|#{Skalp.translate('No')}"], Skalp.translate('SectionPlane')

            no_skalp_section = false

            if result
              ui_create_scene = result[0]
              Sketchup.write_default('Skalp', 'default_inputbox_create_scene', ui_create_scene)
            else
              no_skalp_section = true
            end

            unless no_skalp_section
              status = Skalp.status
              Skalp.status = 0
              entity.set_attribute('Skalp', 'sectionplane_name', entity.name)
              Skalp.status = status
              @model.make_scene = (ui_create_scene == Skalp.translate('Yes') ? true : false)
              @model.add_sectionplane(entity, true)
            end

            @model.commit
            @add_sectionplane = false
          end
        end

        ############### stukje ControlCenter
        if @process_entities
          update_processed_entities(@processed_entities_queue)
          @process_entities = false
        end

        if @update_needed && (@tool_changed || @tool_finished)
          replace_section
          @tool_changed = false
          @update_needed = false
        else
          @tool_changed = false
        end

        @process_queue_busy = false
        restart_queue_timer if @action_queue != []
        @add_sectionplane_finished = true
        #############

      else
        Skalp::new_sectionplane = entity
        @process_queue_busy = false
        restart_queue_timer if @action_queue != []
      end
    }
  else
    @model.tree.skpEntities_add(entity)
  end
end

