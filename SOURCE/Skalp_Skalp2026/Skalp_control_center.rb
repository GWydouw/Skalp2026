module Skalp
  class ControlCenter
    attr_accessor :update_timer_id, :action_queue, :model, :undo_action,
                  :active_page, :active_pagename, :undo_page_switch, :page_undo_stack,
                  :process_queue_busy

    def initialize(model)
      @model = model
      @skpModel = @model.skpModel
      @update_timer_id = nil
      @action_queue = []
      @process_queue_busy = false
      @action_queue_temp = []
      @queue_history = []
      @update_needed = false
      @process_entities = false

      @undo_status = false
      @undo_timer_id = nil
      @observer_status = true
      @observer_flag = false
      @process_queue_busy = false
      @undo_action = {}

      @last_used_tool = 21_022 # selectiontool
      @tool_finished = true
      @tool_changed = false
      @operation = false
      @finish_operation = false
      @active_page = nil
      @active_pagename = nil
      @undo_page_switch = false
      @page_switch = false
    end

    def undoredo(action_queue)
      action_queue.each do |action|
        if %i[undo_transaction redo_transaction].include?(action[:action])
          @model.undoredo_action = true
          return
        end
      end
      @model.undoredo_action = false
    end

    def add_to_queue(data = nil)
      # pp "Add to queue: #{data}"
      if @process_queue_busy
        @action_queue_temp << data if data
      else
        if @action_queue_temp
          for action in @action_queue_temp
            @action_queue << action
          end
          @action_queue_temp = []
        end
        @action_queue << data if data
        restart_queue_timer
      end
    end

    def restart_queue_timer
      UI.stop_timer(@update_timer_id) if !@update_timer_id.nil? || Sketchup.active_model.nil?
      @update_timer_id = UI.start_timer(0.1, false) { process_queue } if Sketchup.active_model
    end

    # ACTIONS
    def geometry_changed(entity)
      return false unless entity
      return false if entity.class == Sketchup::Model

      hidden_status = entity.hidden?
      old_hidden_status = @model.hidden_entities.include?(entity)
      return true unless hidden_status != old_hidden_status

      if hidden_status
        @model.hidden_entities << entity
      else
        @model.hidden_entities.delete(entity)
      end
      false
    end

    def process_queue
      return if Skalp.status == 0
      return if @process_queue_busy

      @process_queue_busy = true
      begin
        @add_sectionplane = false
        @ccA_finished = true
        @set_layers = false
        @root_update = false

      action_queue = @action_queue.slice!(0..-1)
      action_queue.uniq!

      # Skalp.p("#{action_queue}")

      undoredo(action_queue)

      @processed_entities_queue = []

      for action in action_queue

        next unless action[:action]

        # Skalp.p(action.inspect)

        unless (action[:entity] && action[:entity].class == Sketchup::SectionPlane && action[:entity].deleted?) || (action[:entity] && action[:entity].valid?) || (action[:pages] && action[:pages].valid?) || !action[:entity]
          next
        end

        select_action(action)
        if action[:entity] && action[:entity].valid? && geometry_changed(action[:entity])
          @processed_entities_queue << action[:entity]
        end
        @model.tree.undo(action[:entity]) if @model.undoredo_action && action[:entity] && action[:entity].valid?
      end

      unless @add_sectionplane
        if @process_entities
          update_processed_entities(@processed_entities_queue)
          @process_entities = false
        end

        if (@update_needed && (@tool_changed || @tool_finished)) || @page_switch
          replace_section
          @tool_changed = false
          @update_needed = false
          @page_switch = false
        else
          @tool_changed = false
        end


        add_to_queue if @action_queue_temp != []
        restart_queue_timer if @action_queue != []
      end

      @model.tree.root_update_section2D if @root_update

      if @set_layers
        @model.start("Skalp - " + Skalp.translate("set Layer"))
        sectionplane = @model.sectionplane_by_id(@skpModel.entities.active_section_plane)
        sectionplane.section.manage_sections if sectionplane
        @model.commit
      end

      @add_sectionplane = false if @add_sectionplane_finished

      Skalp.dialog.update unless !Skalp.dialog && @model.undoredo_action

    # TODO: turn off animated update gif
    # Skalp.dialog.script("$('#sections_update').attr('src','icons/update_icon_grey.png')")

    # if action[:action]==:undo_transaction && Skalp::Material_dialog::materialdialog && action[:paint_tool]
    # TODO something to fix undo problem with the paint tool
    # end
    rescue StandardError => e
      Skalp.errors(e)
    ensure
      @process_queue_busy = false
    end
  end

    def noUndo
    end

    def update_dialog_after_undorredo
      return unless @skpModel

      if Skalp.dialog
        Skalp.dialog.update_styles(@skpModel.pages.selected_page) if @skpModel.pages.selected_page

        # active sectionplane
        sectionplane = @model.sectionplane_by_id(@model.get_memory_attribute(@skpModel, "Skalp",
                                                                             "active_sectionplane_ID"))
        if sectionplane && sectionplane.skpSectionPlane.valid?
          Skalp.dialog.script("sections_switch_toggle(true)")
          Skalp.dialog.webdialog.execute_script("document.getElementById('sections_list').value = '#{sectionplane.skpSectionPlane.get_attribute(
            'Skalp', 'sectionplane_name'
          )}'")
          Skalp.sectionplane_active = true
        else
          Skalp.dialog.script("sections_switch_toggle(false)")
          Skalp.dialog.webdialog.execute_script("document.getElementById('sections_list').value = '- #{NO_ACTIVE_SECTION_PLANE} -'")
          Skalp.sectionplane_active = false
        end
      end

      Skalp.update_layers_dialog if Skalp.layers_dialog

      @model.undoredo_action = false
    end

    def update_processed_entities(processed_entities)
      return unless processed_entities

      only_faces = only_faces?(processed_entities)
      processed_entities += find_face_parents(processed_entities.grep(Sketchup::Face))
      to_process = entities_to_process(processed_entities)

      for entity in to_process
        next if entity.deleted?

        @model.tree.skpEntity_update_transformation(entity) unless only_faces
        @model.tree.skpEntity_update_section2D(entity)
      end
    end

    def only_faces?(entities)
      entities.each { |e| return false if e.class != Sketchup::Face }
      true
    end

    def entities_to_process(processed_entities)
      to_process = Set.new
      processed_entities.each do |e|
        to_process << e if [Sketchup::Group, Sketchup::ComponentInstance].include?(e.class)
      end
      to_process
    end

    def find_face_parents(faces)
      face_parents = []
      for face in faces
        next unless face.valid?

        # face.parent.class == Sketchup::Model
        face_parents += face.parent.instances if face.parent && face.parent.class == Sketchup::ComponentDefinition
        @root_update = true if face.parent.class == Sketchup::Model
      end
      face_parents
    end
  end
end
