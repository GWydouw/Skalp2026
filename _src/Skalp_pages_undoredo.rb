module Skalp
  class PagesUndoRedo
    attr_accessor :redostack, :undostack, :old_memory_attributes

    # SketchUp (http://help.sketchup.com/en/article/114252)
    # Use the Undo menu item to undo the last drawing or editing commands performed. SketchUp allows you to undo all
    # operations you have performed, one at a time, to the state at which you saved your file. The number of possible
    # sequential Undo commands is limited to 100 steps.

    UNDOBUFFER = 100 unless defined? UNDOBUFFER
    TEST_STACK = true unless defined? TEST_STACK

    def initialize(model)
      @model = model
      @skpModel = @model.skpModel
      create_page_undo_stack
    end

    def create_page_undo_stack
      @undostack = Array.new(UNDOBUFFER, nil)
      @redostack = []
    end

    # DEPRECATED SU2026: Custom undo stack no longer used
    # Native SketchUp undo now handles scene state
    def add_status(status)
      # @redostack = []
      # @undostack << status
      # @undostack.shift
      #puts "ADD status"
      #puts status
    end

    # DEPRECATED SU2026: Custom undo stack no longer used
    def stack_undo
      return nil  # Native undo handles this now
      # Original code below for reference:
      # return unless @skpModel.get_attribute('Skalp', 'page_undo')
      # time = @skpModel.get_attribute('Skalp', 'page_undo').to_i
      # memory_time = @model.get_memory_attribute(@skpModel, 'Skalp', 'page_undo').to_i

      while time != memory_time
        status = @undostack.pop
        @undostack.unshift(nil)
        @redostack << status
        break if @undostack.last == nil
        memory_time = @undostack.last[@skpModel]["page_undo"].to_i if @undostack.last[@skpModel]
        #Skalp.active_model.show_undo
      end

      return @undostack.last
    end

    # DEPRECATED SU2026: Custom undo stack no longer used
    def stack_redo
      return nil  # Native redo handles this now
      # Original code below for reference:
      # return unless @skpModel.get_attribute('Skalp', 'page_undo')
      # time = @skpModel.get_attribute('Skalp', 'page_undo').to_i
      # memory_time = @model.get_memory_attribute(@skpModel, 'Skalp', 'page_undo').to_i

      while time != memory_time
        status = @redostack.pop
        @undostack << status
        @undostack.shift
        memory_time = @undostack.last[@skpModel]["page_undo"].to_i if @undostack.last[@skpModel]
      end

      return @undostack.last
    end

    def undo
      status = stack_undo
      if status
        revert_to_status(status)
      else
        UI.messagebox("Skalp: #{Skalp.translate('extension stopped by undo.')}")
        Skalp.stop_skalp
      end
    end

    def redo
      status = stack_redo
      revert_to_status(status) if status
    end

    def sectionplane_added?
      Sketchup.active_model.entities.grep(Sketchup::SectionPlane).each do |skpSectionplane|
        if skpSectionplane.get_attribute('Skalp', 'ID') && @model.sectionplanes[skpSectionplane] == nil
          @model.add_sectionplane(skpSectionplane, false)
          set_active_sectionplane_to_scenes(skpSectionplane)
        end
      end

      @model.load_sectionplanes
    end

    def revert_to_status(status)
      #puts "REVERT TO STATUS:"
      #puts status

      sectionplane_added?

      @model.dialog_undo_flag = true
      @model.page_undo = true
      observer_status = @model.observer_active
      @model.observer_active = false

      @old_memory_attributes = @model.memory_attributes.dup
      @model.memory_attributes = status.dup

      if @model.get_memory_attribute(@skpModel, 'Skalp', 'selected_page') != Sketchup.active_model.pages.selected_page
        selected_page = @model.get_memory_attribute(@skpModel, 'Skalp', 'selected_page')
        @skpModel.pages.selected_page = selected_page if (selected_page && Skalp.page_valid?(selected_page))
      end

      # if @model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID') == '' || @model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID') == nil
      #   if @skpModel.entities.active_section_plane != nil
      #     #UI.messagebox('breaks undo/redo - OK case 1')  #TODO messagebox verwijderen
      #     #@skpModel.entities.active_section_plane = nil     #breaks undo/redo
      #   end
      # elsif @skpModel.entities.active_section_plane == nil
      #   sectionplane = @model.sectionplane_by_id(@model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')).skpSectionPlane
      #   if sectionplane && sectionplane.valid?
      #     #UI.messagebox('breaks undo/redo - OK case 2')  #TODO messagebox verwijderen
      #     #@skpModel.entities.active_section_plane = sectionplane   #breaks undo/redo
      #   end
      # elsif @skpModel.entities.active_section_plane != nil && (@model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID') != @skpModel.entities.active_section_plane.get_attribute('Skalp', 'ID'))
      #   sectionplane = @model.sectionplane_by_id(@model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')).skpSectionPlane
      #   if sectionplane && sectionplane.valid?
      #     #UI.messagebox('breaks undo/redo - OK case 3')  #TODO messagebox verwijderen
      #     #@skpModel.entities.active_section_plane = sectionplane   #breaks undo/redo
      #   end
      # end

      Sketchup.active_model.pages.each do |page|
        if status.active_sectionplane_changed(page, @old_memory_attributes)

          #@model.start('Skalp - undo active sectionplane')
          sectionplane = @model.sectionplane_by_id(@model.get_memory_attribute(page, 'Skalp', 'sectionplaneID'))
          set_sectionplane_active_in_page(page, sectionplane)
          correct_layers_in_page(page, sectionplane)
          #@model.commit
        end
      end

      update_dialog

      @model.page_undo = false
      @model.observer_active = observer_status

      Skalp.dialog.webdialog.execute_script("$('#UNDO_FLAG').val('').change();") if Skalp.dialog
    end

    def correct_layers_in_page(page, sectionplane)
      pageID = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'ID')

      if sectionplane
        for layer in @skpModel.layers

          if layer.get_attribute('Skalp', 'ID') == pageID || layer.get_attribute('Skalp', 'ID') == sectionplane.skalpID
            page.set_visibility(layer, true)
          else
            if layer.get_attribute('Skalp', 'ID')
              page.set_visibility(layer, false)
            end
          end
        end
      end
    end

    def show_stack
      return unless TEST_STACK
      puts "--- REDO STACK #{@redostack.size}"
      @redostack.each do |status|
        next unless status
        puts status
      end
      puts "--- UNDO STACK #{@undostack.size}"
      @undostack.reverse.each do |status|
        next unless status
        next unless @skpModel && status[@skpModel]
        puts status
      end
      puts '---'
    end

    # MIGRATION SU2026: Changed from abort_operation to commit
    # Native undo now handles scene changes automatically
    def set_active_sectionplane_to_scenes(skpSectionplane)
      @model.force_start("Skalp - #{Skalp.translate('save active Section Plane to scene')}")
      @skpModel.entities.active_section_plane = skpSectionplane

      @skpModel.pages.each do |page|
        if @model.get_memory_attribute(page, 'Skalp', 'sectionplaneID') == skpSectionplane.get_attribute('Skalp', 'ID')
          page.update(64) if (page && Skalp.page_valid?(page))
        end
      end
      @model.commit
    end

    # MIGRATION SU2026: Changed from abort_operation to commit
    # Native undo now handles scene changes automatically
    def set_sectionplane_active_in_page(page, sectionplane)
      return unless page && Skalp.page_valid?(page)

      @model.force_start("Skalp - #{Skalp.translate('save active Section Plane to scene')}")
      sectionplane ? @skpModel.entities.active_section_plane = sectionplane.skpSectionPlane :
          @skpModel.entities.active_section_plane = nil
      page.update(64)
      @model.commit
    end

    def update_dialog
      if Skalp.dialog
        if @skpModel.pages.selected_page
          Skalp.dialog.update_styles(@skpModel.pages.selected_page)
        else
          Skalp.dialog.update_styles(@skpModel)
        end

        Skalp.dialog.get_sectionplanes

        # set active sectionplane
        skpSectionplane = Sketchup.active_model.entities.active_section_plane
        sectionplane = @model.sectionplane_by_id(skpSectionplane.get_attribute('Skalp', 'ID')) if skpSectionplane
        if sectionplane
          Skalp.dialog.script("sections_switch_toggle(true)")
          Skalp.dialog.webdialog.execute_script("document.getElementById('sections_list').value = '#{sectionplane.skpSectionPlane.get_attribute('Skalp', 'sectionplane_name')}'")
          Skalp.sectionplane_active = true
        else
          Skalp.dialog.script("sections_switch_toggle(false)")
          Skalp.dialog.webdialog.execute_script("document.getElementById('sections_list').value = '- #{NO_ACTIVE_SECTION_PLANE} -'")
          Skalp.sectionplane_active = false
        end
      end

      if Skalp.layers_dialog
        Skalp.update_layers_dialog
      end
    end
  end

end