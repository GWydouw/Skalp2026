  def ccA(entities, entity_id)

    if entity_id.class == Integer
      result = @model.tree.skpEntities_delete(entity_id)
    else
      result = @model.tree.skpEntities_delete_from_tree(entity_id)
    end

    @root_update = true if result==true && entities.parent.class == Sketchup::Model

    if result == false
       if @model.active_context.class == Sketchup::Model
         @root_update = true
       elsif entities.parent.class != Sketchup::Model
         nodes = @model.tree.find_nodes_by_id(entities.parent.instances.first.entityID)
         for node in nodes
           node.get_section_results(@model.active_sectionplane.section, true) if @model.active_sectionplane
         end
       end
    end

  rescue TypeError
   #do nothing
  end
