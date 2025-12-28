module Skalp
  class Node_info

    attr_accessor :id, :transformation, :skpEntity, :section_material, :tag, :su_material, :su_material_used_by_hatch, :layer, :layer_used_by_hatch, :visibility, :faces, :section_results,
                  :transformation_obj, :object, :parent, :skpDefinition_entities, :node, :top_parent,
                  :multi_tags, :multi_tags_hatch

    def initialize(node, object, parent = nil)
      @object = object
      @parent = parent
      @node = node

      if @object.is_a?(Sketchup::Model)
        @tag = ''
        @id = @object.path
        @layer = 'Layer0'
        @layer_used_by_hatch = 'Layer0'
        @multi_tags = {}
        @visibility = nil
        @section_material = 'Skalp default'
        @su_material = nil
        @su_material_used_by_hatch = nil
        @transformation = Geom::Transformation.new
        @transformation_obj = @transformation
        @skpEntity = @object
        @skpDefinition_entities = @object.entities
        @top_parent = @node #OK
      else
        @skpEntity = @object
        @id = @skpEntity.entityID.to_s

        @skpEntity = skpEntity
        @skpDefinition_entities = Skalp.get_definition_entities(@skpEntity)

        if @skpEntity.layer.name == 'Layer0' then
          @layer = parent.value.layer
          layer_inside = Skalp.layer_inside_object(@skpEntity)
          layer_inside != 'Layer0' ? @layer_used_by_hatch = layer_inside : @layer_used_by_hatch = @layer
        else
          @layer = @skpEntity.layer.name
          @layer_used_by_hatch = @layer
        end

        @visibility = @skpEntity.visible?

        if @skpEntity.material then
          @su_material = @skpEntity.material
          @su_material_used_by_hatch = @su_material
        else
          @su_material = parent.value.su_material
          material = Skalp.material_inside_object(@skpEntity)
          material ? @su_material_used_by_hatch = material : @su_material_used_by_hatch = @su_material
        end

        get_sectionmaterial
        get_tag
        get_multi_tags

        @transformation_obj = @object.transformation

        if @parent.value.skpEntity.class == Sketchup::Model || @parent == nil
          @transformation = @object.transformation
        else
          @transformation = @parent.value.transformation * @object.transformation
        end

        if @parent.value.top_parent && !@parent.value.top_parent.value.skpEntity.is_a?(Sketchup::Model)
          @top_parent = @parent.value.top_parent
        else
          @top_parent = @node
        end

      end

      @section_results = {}
    end

    def get_layer
      return unless @skpEntity.valid?

      if @skpEntity.layer.name == 'Layer0'
        layer_inside_object = Skalp.layer_inside_object(@skpEntity)
        return if @layer_used_by_hatch == layer_inside_object
      else
        return if @layer_used_by_hatch == @skpEntity.layer.name
      end

      @section_results = {}

      if @skpEntity.layer.name == 'Layer0' then
        @layer = parent.value.layer
        @layer_used_by_hatch = @layer
      else
        @layer = @skpEntity.layer.name
        @layer_used_by_hatch = @layer
      end
    end

    def get_su_material
      return unless @skpEntity.valid?

      return if @su_material != nil && @su_material.valid? && @su_material_used_by_hatch == Skalp.material_inside_object(@skpEntity)
      @section_results = {}

      if @skpEntity.material
        @su_material = @skpEntity.material
        @su_material_used_by_hatch = @su_material
      else
        if @parent != nil
          material = Skalp.material_inside_object(@skpEntity)
          @su_material = @parent.value.su_material
          material ? @su_material_used_by_hatch = material : @su_material_used_by_hatch = @su_material
        end
      end
    end

    def get_tag
      return unless @skpEntity.valid?
      return if @tag == @skpEntity.get_attribute('Skalp', 'tag')

      @section_results = {}

      if @skpEntity.get_attribute('Skalp', 'tag')
        @tag = @skpEntity.get_attribute('Skalp', 'tag')
      else
        @tag = @parent.value.tag if @parent != nil
      end
    end

    def get_multi_tags
      return unless @skpEntity.valid?

      if @skpEntity.get_attribute('AW', 'Tags')
        @multi_tags = eval(@skpEntity.get_attribute('AW', 'Tags'))
        @multi_tags_hatch = get_multitags_hatch
      else
        if @parent != nil
          @multi_tags = @parent.value.multi_tags
          @multi_tags_hatch = get_multitags_hatch
        end
      end
    end

    def get_multitags_hatch
      section_table = Skalp::active_model.multi_tags_sectionmaterial_table
      groups = Skalp::active_model.multi_tags_groups_for_section

      tag = []
      groups.each do |group|
        tag << @multi_tags[group]
      end

      section_table.each do |rule, hatch|
        i = rule.index('*')
        if i
          return hatch if rule[0..i-1] == tag[0..i-1]
        else
          return hatch if rule == tag
        end
      end

      return nil
    end

    def get_sectionmaterial
      return unless @skpEntity.valid?

      if @skpEntity.get_attribute('Skalp', 'sectionmaterial')
        @section_material = @skpEntity.get_attribute('Skalp', 'sectionmaterial')
      else
        @section_material = @parent.value.section_material if @parent != nil
      end
    end

    def update_section_result(sectionplane)
      return unless sectionplane.skpSectionPlane.valid?

      if @section_results.include?(sectionplane)
        section_result = @section_results[sectionplane]
        section_result.reset
      else
        section_result = Section2D.new(@node)
        @section_results[sectionplane] = section_result
      end
      section_result.section_material = @section_material

      @SectionAlgorithm || (@SectionAlgorithm = Skalp::SectionAlgorithm.new)
      @SectionAlgorithm.calculate_section(@skpEntity, @transformation, sectionplane)
      polygons = @SectionAlgorithm.polygons

      section_result.add_polygons(polygons) if polygons != nil
    end
  end

  class TreeNode
    attr_accessor :name, :parents, :children, :value, :root, :parent, :tree

    @@unique_tel = 0

    def initialize(object, parent, tree)
      @@unique_tel += 1
      @tree = tree
      if object.class == Sketchup::Model
        @name = 'id_' + (Skalp::active_filename).gsub(' ', '_')
        @parent = nil
        @value = Node_info.new(self, object)
      else
        @tree.lookup_table_by_id[@@unique_tel] = object.entityID
        @name = 'id_' + @@unique_tel.to_s
        @parent = parent
        @value = Node_info.new(self, object, parent)
      end

      @parents = []
      @children = []

      parent.addChild(self) if parent != nil
      @tree.cache[@name] = self if @tree.cachingEnabled == true

      objects = value.skpDefinition_entities.grep(Sketchup::Group) + value.skpDefinition_entities.grep(Sketchup::ComponentInstance) if value.skpDefinition_entities
      return if not objects

      for obj in objects
        obj.deleted? && next
        obj.get_attribute('Skalp', 'ID') && next
        TreeNode.new(obj, self, @tree)
      end
    end

    def root
      return @root if parent == nil
      @root = parent.root
    end

    def addParent(parent)
      @parents.push(parent) if (parent != nil) and (not @parents.include? parent)
    end

    def addChild(child)
      return if child == nil
      child.addParent(self)
      @children.push(child) if not @children.include? child
    end

    def removeChild(child)
      child.removeParent(self)
      @children.delete(child)
    end

    def deleteChildren
      for node in @children
        node.deleteChildren
        @tree.removeNode(node)
        node = nil
      end
      @children =[]
    end

    def set_modified
      @value.section_results = {}
    end

    def refresh(skpEntity)
      @value.section_results = {}
      self.deleteChildren
      for e in Skalp.get_definition_entities(skpEntity).grep(Sketchup::Group)
        TreeNode.new(e, self, @tree)
      end
      for e in Skalp.get_definition_entities(skpEntity).grep(Sketchup::ComponentInstance)
        TreeNode.new(e, self, @tree)
      end
    end

    def removeParent(parent)
      @parents.delete(parent)
      # If we have no parents left we need to remove ourself
      @children.dup.each { |child| self.removeChild(child) } if parents.size == 0
    end

    def set_visibility(section)
      return unless @value.skpEntity
      return unless @value.skpEntity.valid?

      if @value.skpEntity.class == Sketchup::Model
        @value.visibility = true
      else
        return unless @value.skpEntity.layer.valid?

        if @parent == nil
          parent_visibility = true
        else
          parent_visibility = @parent.value.visibility
        end

        if section && section.visibility
          if section.visibility.include_layer?(@value.skpEntity.layer) || section.visibility.include_hidden_entity?(@value.skpEntity) || parent_visibility == false
            @value.visibility = false
          else
            @value.visibility = true
          end
        end
      end
    end

    def calculate_section(sectionplane)
      return if @value.skpEntity.valid? == false
      @value.update_section_result(sectionplane) if @value.visibility == true
    end

    def get_section_results(section, force_update = false, update_children = true, nodes_to_exclude = [])
      return if section.sectionplane == nil
      set_visibility(section) #TODO moet er nog verder gerekend worden indien niet zichtbaar?

      if @value.section_results[section.sectionplane] == nil || force_update == true
        result = calculate_section(section.sectionplane)
      end

      if result || @value.section_results[section.sectionplane] != nil
        result2D = @value.section_results[section.sectionplane]
        section.section2Ds << result2D if result2D.meshes && !result2D.meshes.empty?
      end

      @value.visibility || return

      if update_children
        for node in @children
          return if nodes_to_exclude.include?(node)
          node.get_section_results(section, force_update, update_children, nodes_to_exclude)
        end
      end
    end

    def update_transformation
      return unless self.value.skpEntity.valid?

      if self.value.skpEntity.class != Sketchup::Model

        if @tree.skpModel.active_path != nil
          if @tree.skpModel.active_path.include?(self.value.skpEntity) && @tree.skpModel.active_path.include?(self.parent.value.skpEntity) == false
            self.value.transformation = Geom::Transformation.new
          end
          if @tree.skpModel.active_path.include?(self.value.skpEntity) && @tree.skpModel.active_path.include?(self.parent.value.skpEntity)
            self.value.transformation = Geom::Transformation.new
          end
          if @tree.skpModel.active_path.include?(self.parent.value.skpEntity) && @tree.skpModel.active_path.include?(self.value.skpEntity) == false
            self.value.transformation = self.value.skpEntity.transformation
          end
          if @tree.skpModel.active_path.include?(self.value.skpEntity) == false && @tree.skpModel.active_path.include?(self.parent.value.skpEntity) == false
            self.value.transformation = self.parent.value.transformation * self.value.skpEntity.transformation
          end
        else
          self.value.transformation = self.parent.value.transformation * self.value.skpEntity.transformation
        end
      end

      for node in @children
        node.update_transformation
      end

    rescue => e
      Skalp.errors(e)
    end

    def update_su_material
      @value.get_su_material
      for node in @children
        node.update_su_material
      end
    end

    def update_layer
      @value.get_layer
      for node in @children
        node.update_layer
      end
    end

    def update_sectionmaterial
      @value.get_sectionmaterial
      for node in @children
        node.update_sectionmaterial
      end
    end

    def update_tag
      @value.get_tag
      for node in @children
        node.update_tag
      end
    end

    def update_multi_tags
      @value.get_multi_tags
      for node in @children
        node.update_multi_tags
      end
    end

    def inspect
      return @name
    end
  end # class TreeNode

  class Tree
    attr_accessor(:root, :cachingEnabled, :cache, :lookup_table_by_id, :skpModel)

    def initialize(skpModel)
      @skpModel = skpModel
      @cache = {}
      @lookup_table_by_id = {}
      @cachingEnabled = true
      @root = TreeNode.new(@skpModel, nil, self)
      Skalp.message1 unless Skalp.guid == Sketchup.read_default('Skalp', 'guid')
    end

    def print(node, depth)
      if node.value.skpEntity.class != Sketchup::Model && node.value.skpEntity.deleted?
        puts "#{depth} #{node.name} Ent #{node.value.skpEntity} DELETED "
      else
        puts "#{depth} #{node.name} Ent #{node.value.skpEntity} ID #{node.value.skpEntity.entityID} transf: #{node.value.transformation.to_a.inspect}  " if node.value.skpEntity.class != Sketchup::Model
        result = node.value.section_results[0]
      end
      depth = depth + '--'
      for child in node.children
        self.print(child, depth)
      end
    end

    def test_tree (node=@root)
      observer_status = Skalp.active_model.observer_active
      Skalp.active_model.observer_active = false
      layer = @skpModel.layers.add('skalp tree') if not @skpModel.layers.include?('skalp tree')

      for face in node.value.skpEntity.entities.grep(Sketchup::Face)
        edges=[]
        for edge in face.edges
          edges << @skpModel.entities.add_line(node.value.transformation * edge.start.position, node.value.transformation * edge.end.position)
        end
        face = @skpModel.entities.add_face(edges)
        for edge in edges
          edge.layer = layer if edge != nil
        end
        face.material = "red" if face != nil
        face.layer = layer if face != nil
      end

      for child in node.children
        self.test_tree(child)
      end
      Skalp.active_model.observer_active = observer_status
    end

    def printroot
      self.print(@root, '')
    end

    def removeNode(nodeName)
      node = self.findNode(nodeName)
      @cache.delete nodeName if @cachingEnabled
      node.parents.dup.each { |parent| parent.removeChild(node) } if node != nil
    end

    def findNode(nodeName)
      if @cachingEnabled
        foundNode = @cache[nodeName]
        if foundNode != nil
          return foundNode
        end
      end
      return nil if @cachingEnabled

      ret = nil
      self.depthFirst() do |node|
        if node.name == nodeName
          ret = node
          break
        end
      end
      return ret
    end

    def find_nodes_by_id(id)
      node_id_array = @lookup_table_by_id.select { |k, v| v == id }
      nodes = []
      for node_id in node_id_array
        nodes << self.findNode('id_' + node_id[0].to_s)
      end
      return nodes.compact
    end

    def skpEntity_update_transformation(entity)
      return if entity.deleted?
      for node in find_nodes_by_id(entity.entityID)
        node.update_transformation
      end
    end

    def skpEntity_update_su_material(entity)
      return if entity.deleted?
      nodes_to_update = find_nodes_by_id(entity.entityID)

      for node in nodes_to_update
        node.update_su_material
      end
    end

    def skpEntity_update_layer(entity)
      return if entity.deleted?
      nodes_to_update = find_nodes_by_id(entity.entityID)

      for node in nodes_to_update
        node.update_layer
      end
    end

    def skpEntity_update_sectionmaterial(entity)
      return if entity.class == Sketchup::Model
      return if entity.deleted?
      nodes_to_update = find_nodes_by_id(entity.entityID)

      for node in nodes_to_update
        node.update_sectionmaterial
      end
    end

    def skpEntity_update_tag(entity)
      return if entity.deleted?
      nodes_to_update = find_nodes_by_id(entity.entityID)

      for node in nodes_to_update
        node.update_tag
      end
    end

    def skpEntity_update_multi_tags(entity)
      return if entity.deleted?
      nodes_to_update = find_nodes_by_id(entity.entityID)

      for node in nodes_to_update
        node.update_multi_tags
      end
    end

    def skpEntity_update_section2D(entity)
      return if entity.deleted?
      return unless Skalp.active_model

      Skalp.active_model.model_changes = true
      Skalp.dialog.model_changed

      nodes_to_update = []
      force_update = true

      if entity.is_a?(Sketchup::Face)
        update_children = false
        if entity.parent == @skpModel
          nodes_to_update << @root
        else
          nodes_to_update = find_nodes_by_id(Skalp.active_model.active_context.entityID) if Skalp.active_model.class != Sketchup::Model && Skalp.active_model.active_context && Skalp.active_model.active_context.valid?
        end
      else
        update_children = true
        nodes_to_update = find_nodes_by_id(entity.entityID)
      end

      for node in nodes_to_update
        node.set_modified
        node.get_section_results(Skalp.active_model.active_sectionplane.section, force_update, update_children) if Skalp.active_model.active_sectionplane
      end
    end

    def undo(entity)
      skpEntity_update_tag(entity)
      skpEntity_update_sectionmaterial(entity)
      skpEntity_update_layer(entity)
      skpEntity_update_section2D(entity)
      skpEntity_update_su_material(entity)
      skpEntity_update_transformation(entity)
    end

    def root_update_section2D
      @root.get_section_results(Skalp.active_model.active_sectionplane.section, true, false) if Skalp.active_model.active_sectionplane
    end

    def skpEntities_delete_from_tree(entity)
      nodes = find_nodes_by_id(entity.entityID.to_i).compact.uniq
      return false unless nodes

      for node in nodes
        removeNode(node.name)
      end

      return true
    end

    def skpEntities_delete(entityID)
      found_node = false
      nodes = find_nodes_by_id(entityID.to_i).compact.uniq
      return unless nodes

      for node in nodes
        if node.value.skpEntity.deleted?
          found_node = true
          removeNode(node.name)
        else
          removed = true
          parent = node.parent.value.skpEntity
          if parent.valid?
            entities = nil
            suClass = parent.class
            if suClass == Sketchup::Group
              entities = parent.entities
            elsif suClass == Sketchup::ComponentInstance
              entities = parent.definition.entities
            elsif suClass == Sketchup::Model
              entities = parent.entities
            end

            if entities
              entities.each do |e|
                if e.entityID == entityID
                  removed = false
                  break
                end
              end
            end
          end
          removeNode(node.name) if removed == true
        end
      end

      return found_node
    end

    def skpEntities_add(entity)
      return if entity.deleted?
      return unless Skalp.active_model.active_context.class == Sketchup::Model || Skalp.active_model.active_context.valid?

      return if entity.is_a?(Sketchup::SectionPlane)
      if Skalp.object?(entity)
        if Skalp.active_model.active_context != @skpModel
          parents = self.find_nodes_by_id(Skalp.active_model.active_context.entityID) if Skalp.active_model.active_context.class != Sketchup::Model

          if parents
            for parent in parents
              TreeNode.new(entity, parent, self)
            end
          end
        else
          TreeNode.new(entity, @root, self)
        end
      elsif entity.is_a?(Sketchup::Face)
        @root.value.section_results={} if entity.parent.class == Sketchup::Model
      end
    end

    def rebuild_entity(entity)
      skpEntities_delete(entity.entityID)
      skpEntities_add(entity)
    end
  end
end