  def ccA(entity)
    return if entity.deleted?

    if entity.is_a?(Sketchup::ComponentInstance) && entity.attribute_dictionary("dynamic_attributes")
      nodes = @model.tree.find_nodes_by_id(entity.entityID)
      for node in nodes
        node.refresh(entity)
      end
    end

    #Material, layer or tag changed?
    nodes = @model.tree.find_nodes_by_id(entity.entityID)

    unless nodes.first && nodes.first.value
      #Layers or material inside object changed?
      if entity.is_a?(Sketchup::Face) && entity.parent.is_a?(Sketchup::ComponentDefinition)
        nodes = @model.tree.find_nodes_by_id(entity.parent.instances.first.entityID)
        entity = entity.parent.instances.first
      end

      return unless nodes.first
      return unless nodes.first.value
    end

    if (nodes.first.value.su_material && nodes.first.value.su_material.deleted?) || nodes.first.value.su_material_used_by_hatch != Skalp.material_inside_object(entity)
      @model.tree.skpEntity_update_su_material(entity)
    end

    if nodes.first.value.layer_used_by_hatch != Skalp.layer_inside_object(entity)
      @model.tree.skpEntity_update_layer(entity)
    end

    if nodes.first.value.tag != entity.get_attribute('Skalp','tag')
      @model.tree.skpEntity_update_tag(entity)
    end

    if nodes.first.value.multi_tags != entity.get_attribute('AW', 'Tags')
      @model.tree.skpEntity_update_multi_tags(entity)
    end
  end

