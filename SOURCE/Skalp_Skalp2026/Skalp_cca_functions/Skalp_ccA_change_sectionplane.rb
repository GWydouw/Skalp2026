
  def ccA(entity)
    return unless entity.valid?
    hidden_status = entity.hidden?
    old_hidden_status =  @model.hidden_entities.include?(entity)
    if hidden_status == old_hidden_status
      if @model.sectionplanes[entity]
        #Skalp.dialog.model_changed
        @model.sectionplanes[entity].plane = entity.get_plane
        @model.sectionplanes[entity].calculate_section
      end
    end

    if @model.sectionplanes[entity] && @model.sectionplanes[entity].sectionplane_name != entity.name
      @model.sectionplanes[entity].rename(entity.name)
    end

  end
