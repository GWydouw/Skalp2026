
  def ccA(skpSectionplane)
    unless Skalp.active_model.undoredo_action
      @model.delete_sectionplane(@model.sectionplanes[skpSectionplane], true)  if @model.sectionplanes
    else
      deleted_sectionplane =  @model.find_deleted_sectionplane
      @model.delete_sectionplane(deleted_sectionplane, true) if deleted_sectionplane
    end
  end
