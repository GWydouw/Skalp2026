def ccA(sectionplane)
    if @model
      unless @model.undoredo_action
        if @model.on_setup == true
          @model.start("Skalp - #{Skalp.translate('change active sectionplane')}", false)
        else
          @model.start("Skalp - #{Skalp.translate('change active sectionplane')}", true)
        end

        #Skalp.dialog.model_changed
        Skalp.change_active_sectionplane(sectionplane)
        @model.commit

        noUndo if @undo_page_switch
        @undo_page_switch = false
      end
    end
rescue => e
  Skalp.errors(e)

end
