def ccA(model)
  if model.active_path == nil
    if @model.active_context != model.active_path
      if @model.active_context.class == Sketchup::ComponentInstance
        @model.active_context.definition.entities.remove_observer(@model.entities_observer) if @model.active_context.valid? && @model.active_context.definition.valid?
      else
        @model.active_context.entities.remove_observer(@model.entities_observer) if @model.active_context.valid?
      end
      if @skpModel.class == Sketchup::Model
        @model.active_context = @skpModel
        @model.active_context.entities.add_observer(@model.entities_observer) if @model.active_context.entities
      end
    end
  elsif model.active_path.last != @model.active_context
    if @model.active_context.class == Sketchup::ComponentInstance
      @model.active_context.definition.entities.remove_observer(@model.entities_observer)  if @model.active_context.valid? && @model.active_context.definition.valid?
    else
      @model.active_context.entities.remove_observer(@model.entities_observer)  if @model.active_context.valid?
    end
    @model.active_context = model.active_path.last
    if @model.active_context.class == Sketchup::ComponentInstance # @model.active_context.definition.valid?
      @model.active_context.definition.entities.add_observer(@model.entities_observer) && @model.active_context.definition.valid?
    else
      @model.active_context.entities.add_observer(@model.entities_observer) if @model.active_context.valid? && @model.active_context.respond_to?(:entities)
    end
    @model.active_sectionplane.section.section2Ds = [] if @model.active_sectionplane
  end

  @model.tree.root.update_transformation
end
