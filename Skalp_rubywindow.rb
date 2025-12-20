#RubyWindow trigger our que....

Skalp::object_updated(entity) if defined?(Skalp) && Skalp.respond_to?(:object_updated)

module Skalp
  def object_updated(entity)
    if Skalp.status == 1

      if entity.parent.class == Sketchup::ComponentDefinition
        entities = entity.parent.definition.entities
      else
        entities = entity.parent.entities
      end

      data = {
          :action => :removed_element,
          :entities => entities,
          :entity_id => entity
      }
      Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)

      data = {
          :action => :add_element,
          :entities => entities,
          :entity => entity
      }
      Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)

    end
  end
end

