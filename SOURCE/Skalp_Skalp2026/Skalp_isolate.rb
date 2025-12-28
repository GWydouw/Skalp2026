module Skalp
  module Isolate
    @history = []

    def self.send_to_queue(entity)
      return unless Skalp.active_model

      data = {
          :action => :modified_element,
          :entities => Sketchup.active_model.entities,
          :entity => entity
      }
      Skalp.active_model.controlCenter.add_to_queue(data)
    end

    def self.history
      @history
    end

    def self.isolate_selected_entities
      @entities = Sketchup.active_model.active_entities
      selection_to_isolate = Sketchup.active_model.selection
      hidden = Set.new
      @history << hidden

      Skalp.active_model ?
          Skalp.active_model.start('Skalp Isolate - isolate selected entities', true) :
          Sketchup.active_model.start_operation('Skalp Isolate - isolate selected entities', true)

      for e in @entities
        unless selection_to_isolate.include?(e)
          if e.valid? && e.visible? && e.class != Sketchup::SectionPlane && e.get_attribute('Skalp', 'ID')!="skalp_live_sectiongroup"
            e.hidden = true
            hidden << e
          else
            next
          end
        end
        send_to_queue(e)
      end
      selection_to_isolate.clear

      Skalp.active_model ?
          Skalp.active_model.commit :
          Sketchup.active_model.commit_operation
    end

    def self.reveal_previous_entities
      Skalp.active_model ?
          Skalp.active_model.start('Skalp Isolate - reveal previous entities', true) :
          Sketchup.active_model.start_operation('Skalp Isolate - reveal previous entities', true)

      hidden = @history.pop

      for e in hidden
        next unless e.valid?
        e.hidden = false
        send_to_queue(e)
      end

      Skalp.active_model ?
          Skalp.active_model.commit :
          Sketchup.active_model.commit_operation
    end

    def self.reveal_all_entities
      Skalp.active_model ?
          Skalp.active_model.start('Skalp Isolate - reveal all entities', true) :
          Sketchup.active_model.start_operation('Skalp Isolate - reveal all entities', true)

      for hidden in @history
        for e in hidden
          next unless e.valid?
          e.hidden = false
          send_to_queue(e)
        end
      end
      @history = []
      Sketchup.active_model.selection.clear
      Skalp.active_model ?
          Skalp.active_model.commit :
          Sketchup.active_model.commit_operation
    end

    def self.cleanup_history
      cleaned_history = []
      for hidden in @history
        new_hidden = []
        for e in hidden
          next unless e.valid?
          new_hidden << e if e.hidden?
        end
        cleaned_history << new_hidden unless new_hidden == []
      end

      @history = cleaned_history
    end

    if Skalp.isolate_UI_loaded == false
      UI.add_context_menu_handler do |menu|
        cleanup_history
        menu.add_separator

        if Sketchup.active_model.selection.count > 1 ||
            (Sketchup.active_model.selection.count == 1 && Sketchup.active_model.selection.first.get_attribute('Skalp', 'ID')!="skalp_live_sectiongroup")
          menu.add_item("Skalp Isolate - Isolate selected entities") {
            isolate_selected_entities
          }
        end


        if @history.size > 1
          menu.add_item("Skalp Isolate - Reveal previous entities") {
            reveal_previous_entities
          }
        end

        if @history.size > 0
          menu.add_item("Skalp Isolate - Reveal all entities") {
            reveal_all_entities
          }
        end

        menu.add_separator
      end

      Skalp.isolate_UI_loaded = true
    end
  end
end