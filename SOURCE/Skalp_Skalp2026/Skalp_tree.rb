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
        @tag = ""
        @id = @object.path
        @layer = "Layer0"
        @layer_used_by_hatch = "Layer0"
        @multi_tags = {}
        @visibility = nil
        @section_material = "Skalp default"
        @su_material = nil
        @su_material_used_by_hatch = nil
        @transformation = Geom::Transformation.new
        @transformation_obj = @transformation
        @skpEntity = @object
        @skpDefinition_entities = @object.entities
        @top_parent = @node # OK
      else
        @skpEntity = @object
        @id = @skpEntity.entityID.to_s

        @skpEntity = skpEntity
        @skpDefinition_entities = Skalp.get_definition_entities(@skpEntity)

        if @skpEntity.layer.name == "Layer0"
          @layer = parent.value.layer
          layer_inside = Skalp.layer_inside_object(@skpEntity)
          @layer_used_by_hatch = layer_inside == "Layer0" ? @layer : layer_inside
        else
          @layer = @skpEntity.layer.name
          @layer_used_by_hatch = @layer
        end

        @visibility = @skpEntity.visible?

        if @skpEntity.material
          @su_material = @skpEntity.material
          @su_material_used_by_hatch = @su_material
        else
          @su_material = parent.value.su_material
          material = Skalp.material_inside_object(@skpEntity)
          @su_material_used_by_hatch = material || @su_material
        end

        get_sectionmaterial
        get_tag
        get_multi_tags

        @transformation_obj = @object.transformation

        @transformation = if @parent.value.skpEntity.class == Sketchup::Model || @parent.nil?
                            @object.transformation
                          else
                            @parent.value.transformation * @object.transformation
                          end

        @top_parent = if @parent.value.top_parent && !@parent.value.top_parent.value.skpEntity.is_a?(Sketchup::Model)
                        @parent.value.top_parent
                      else
                        @node
                      end

      end

      @section_results = {}
    end

    def inspect
      "#<#{self.class}:#{object_id} @id=#{@id} @skpEntity=#{@skpEntity}>"
    end

    def get_layer
      return unless @skpEntity.valid?

      if @skpEntity.layer.name == "Layer0"
        layer_inside_object = Skalp.layer_inside_object(@skpEntity)
        return if @layer_used_by_hatch == layer_inside_object
      elsif @layer_used_by_hatch == @skpEntity.layer.name
        return
      end

      @section_results = {}

      if @skpEntity.layer.name == "Layer0"
        @layer = parent.value.layer
        @layer_used_by_hatch = @layer
      else
        @layer = @skpEntity.layer.name
        @layer_used_by_hatch = @layer
      end
    end

    def get_su_material
      return unless @skpEntity.valid?

      if !@su_material.nil? && @su_material.valid? && @su_material_used_by_hatch == Skalp.material_inside_object(@skpEntity)
        return
      end

      @section_results = {}

      if @skpEntity.material
        @su_material = @skpEntity.material
        @su_material_used_by_hatch = @su_material
      elsif !@parent.nil?
        material = Skalp.material_inside_object(@skpEntity)
        @su_material = @parent.value.su_material
        @su_material_used_by_hatch = material || @su_material
      end
    end

    def get_tag
      return unless @skpEntity.valid?
      return if @tag == @skpEntity.get_attribute("Skalp", "tag")

      @section_results = {}

      if @skpEntity.get_attribute("Skalp", "tag")
        @tag = @skpEntity.get_attribute("Skalp", "tag")
      elsif !@parent.nil?
        @tag = @parent.value.tag
      end
    end

    def get_multi_tags
      return unless @skpEntity.valid?

      if @skpEntity.get_attribute("AW", "Tags")
        @multi_tags = eval(@skpEntity.get_attribute("AW", "Tags"))
        @multi_tags_hatch = get_multitags_hatch
      elsif !@parent.nil?
        @multi_tags = @parent.value.multi_tags
        @multi_tags_hatch = get_multitags_hatch
      end
    end

    def get_multitags_hatch
      section_table = Skalp.active_model.multi_tags_sectionmaterial_table
      groups = Skalp.active_model.multi_tags_groups_for_section

      tag = []
      groups.each do |group|
        tag << @multi_tags[group]
      end

      section_table.each do |rule, hatch|
        i = rule.index("*")
        if i
          return hatch if rule[0..i - 1] == tag[0..i - 1]
        elsif rule == tag
          return hatch
        end
      end

      nil
    end

    def get_sectionmaterial
      return unless @skpEntity.valid?

      if @skpEntity.get_attribute("Skalp", "sectionmaterial")
        @section_material = @skpEntity.get_attribute("Skalp", "sectionmaterial")
      elsif !@parent.nil?
        @section_material = @parent.value.section_material
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

      section_result.add_polygons(polygons) unless polygons.nil?
    end
  end

  class TreeNode
    attr_accessor :name, :parents, :children, :value, :root, :parent, :tree

    @@unique_tel = 0

    def initialize(object, parent, tree)
      @@unique_tel += 1
      @tree = tree
      if object.class == Sketchup::Model
        @name = "id_" + Skalp.active_filename.gsub(" ", "_")
        @parent = nil
        @value = Node_info.new(self, object)
      else
        @tree.lookup_table_by_id[@@unique_tel] = object.entityID
        @name = "id_" + @@unique_tel.to_s
        @parent = parent
        @value = Node_info.new(self, object, parent)
      end

      @parents = []
      @children = []

      parent.addChild(self) unless parent.nil?
      @tree.cache[@name] = self if @tree.cachingEnabled == true

      if value.skpDefinition_entities
        objects = value.skpDefinition_entities.grep(Sketchup::Group) + value.skpDefinition_entities.grep(Sketchup::ComponentInstance)
      end
      return unless objects

      for obj in objects
        obj.deleted? && next
        obj.get_attribute("Skalp", "ID") && next
        TreeNode.new(obj, self, @tree)
      end
    end

    def root
      return @root if parent.nil?

      @root = parent.root
    end

    def addParent(parent)
      @parents.push(parent) if !parent.nil? and (!@parents.include? parent)
    end

    def addChild(child)
      return if child.nil?

      child.addParent(self)
      @children.push(child) unless @children.include? child
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
      @children = []
    end

    def set_modified
      @value.section_results = {}
    end

    def refresh(skpEntity)
      @value.section_results = {}
      deleteChildren
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
      @children.dup.each { |child| removeChild(child) } if parents.size == 0
    end

    def set_visibility(section)
      return unless @value.skpEntity
      return unless @value.skpEntity.valid?

      if @value.skpEntity.class == Sketchup::Model
        @value.visibility = true
      else
        return unless @value.skpEntity.layer.valid?

        parent_visibility = @parent.nil? || @parent.value.visibility

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
      return if section.sectionplane.nil?

      set_visibility(section) # TODO: moet er nog verder gerekend worden indien niet zichtbaar?

      if @value.section_results[section.sectionplane].nil? || force_update == true
        result = calculate_section(section.sectionplane)
      end

      if result || !@value.section_results[section.sectionplane].nil?
        result2D = @value.section_results[section.sectionplane]
        section.section2Ds << result2D if result2D.meshes && !result2D.meshes.empty?
      end

      @value.visibility || return

      return unless update_children

      for node in @children
        return if nodes_to_exclude.include?(node)

        node.get_section_results(section, force_update, update_children, nodes_to_exclude)
      end
    end

    def update_transformation
      return unless value.skpEntity.valid?

      if value.skpEntity.class != Sketchup::Model

        if @tree.skpModel.active_path.nil?
          value.transformation = parent.value.transformation * value.skpEntity.transformation
        else
          if @tree.skpModel.active_path.include?(value.skpEntity) && @tree.skpModel.active_path.include?(parent.value.skpEntity) == false
            value.transformation = Geom::Transformation.new
          end
          if @tree.skpModel.active_path.include?(value.skpEntity) && @tree.skpModel.active_path.include?(parent.value.skpEntity)
            value.transformation = Geom::Transformation.new
          end
          if @tree.skpModel.active_path.include?(parent.value.skpEntity) && @tree.skpModel.active_path.include?(value.skpEntity) == false
            value.transformation = value.skpEntity.transformation
          end
          if @tree.skpModel.active_path.include?(value.skpEntity) == false && @tree.skpModel.active_path.include?(parent.value.skpEntity) == false
            value.transformation = parent.value.transformation * value.skpEntity.transformation
          end
        end
      end

      for node in @children
        node.update_transformation
      end
    rescue StandardError => e
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
      @name
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
      Skalp.message1 unless Skalp.guid == Sketchup.read_default("Skalp", "guid")
    end

    def print(node, depth)
      if node.value.skpEntity.class != Sketchup::Model && node.value.skpEntity.deleted?
        puts "#{depth} #{node.name} Ent #{node.value.skpEntity} DELETED "
      else
        if node.value.skpEntity.class != Sketchup::Model
          puts "#{depth} #{node.name} Ent #{node.value.skpEntity} ID #{node.value.skpEntity.entityID} transf: #{node.value.transformation.to_a.inspect}  "
        end
        result = node.value.section_results[0]
      end
      depth += "--"
      for child in node.children
        self.print(child, depth)
      end
    end

    def test_tree(node = @root)
      observer_status = Skalp.active_model.observer_active
      Skalp.active_model.observer_active = false
      layer = @skpModel.layers.add("skalp tree") unless @skpModel.layers.include?("skalp tree")

      for face in node.value.skpEntity.entities.grep(Sketchup::Face)
        edges = []
        for edge in face.edges
          edges << @skpModel.entities.add_line(node.value.transformation * edge.start.position,
                                               node.value.transformation * edge.end.position)
        end
        face = @skpModel.entities.add_face(edges)
        for edge in edges
          edge.layer = layer unless edge.nil?
        end
        face.material = "red" unless face.nil?
        face.layer = layer unless face.nil?
      end

      for child in node.children
        test_tree(child)
      end
      Skalp.active_model.observer_active = observer_status
    end

    def printroot
      self.print(@root, "")
    end

    def removeNode(nodeName)
      node = findNode(nodeName)
      @cache.delete nodeName if @cachingEnabled
      node.parents.dup.each { |parent| parent.removeChild(node) } unless node.nil?
    end

    def findNode(nodeName)
      if @cachingEnabled
        foundNode = @cache[nodeName]
        return foundNode unless foundNode.nil?
      end
      return nil if @cachingEnabled

      ret = nil
      depthFirst do |node|
        if node.name == nodeName
          ret = node
          break
        end
      end
      ret
    end

    def find_nodes_by_id(id)
      node_id_array = @lookup_table_by_id.select { |k, v| v == id }
      nodes = []
      for node_id in node_id_array
        nodes << findNode("id_" + node_id[0].to_s)
      end
      nodes.compact
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
        elsif Skalp.active_model.class != Sketchup::Model && Skalp.active_model.active_context && Skalp.active_model.active_context.valid?
          if Skalp.active_model.class != Sketchup::Model && Skalp.active_model.active_context && Skalp.active_model.active_context.valid?
            nodes_to_update = find_nodes_by_id(Skalp.active_model.active_context.entityID)
          end
        end
      else
        update_children = true
        nodes_to_update = find_nodes_by_id(entity.entityID)
      end

      for node in nodes_to_update
        node.set_modified
        if Skalp.active_model.active_sectionplane
          node.get_section_results(Skalp.active_model.active_sectionplane.section, force_update,
                                   update_children)
        end
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
      return unless Skalp.active_model.active_sectionplane

      @root.get_section_results(Skalp.active_model.active_sectionplane.section, true,
                                false)
    end

    def skpEntities_delete_from_tree(entity)
      nodes = find_nodes_by_id(entity.entityID.to_i).compact.uniq
      return false unless nodes

      for node in nodes
        removeNode(node.name)
      end

      true
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

      found_node
    end

    def skpEntities_add(entity)
      return if entity.deleted?
      unless Skalp.active_model.active_context.class == Sketchup::Model || Skalp.active_model.active_context.valid?
        return
      end

      return if entity.is_a?(Sketchup::SectionPlane)

      if Skalp.object?(entity)
        if Skalp.active_model.active_context == @skpModel
          TreeNode.new(entity, @root, self)
        else
          if Skalp.active_model.active_context.class != Sketchup::Model
            parents = find_nodes_by_id(Skalp.active_model.active_context.entityID)
          end

          if parents
            for parent in parents
              TreeNode.new(entity, parent, self)
            end
          end
        end
      elsif entity.is_a?(Sketchup::Face)
        @root.value.section_results = {} if entity.parent.class == Sketchup::Model
      end
    end

    def rebuild_entity(entity)
      skpEntities_delete(entity.entityID)
      skpEntities_add(entity)
    end
  end
end
