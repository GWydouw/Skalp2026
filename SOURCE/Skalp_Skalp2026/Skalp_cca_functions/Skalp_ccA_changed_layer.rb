
  def ccA(layer)
    @model.active_sectionplane.calculate_section(false) if @model && @model.active_sectionplane
  end
