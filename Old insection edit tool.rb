
class SkalpSelect
  def activate
    @selected_objects = []
    @selected_section_faces = []
    @temp_selected_faces = []
    @temp_selected_objects = []

    @cursor_type = 1
    @cursor_Skalp_id = UI.create_cursor(IMAGE_PATH + "cursor_Skalp_Select.png", 0, 0) #1
    @cursor_SU_id = UI.create_cursor(IMAGE_PATH + "cursor_SU_Select.png", 0, 0) #0
    @cursor_SkalpAdd_id = UI.create_cursor(IMAGE_PATH + "cursor_Skalp_SelectAdd.png", 0, 0) #2
    @cursor_SkalpInvert_id = UI.create_cursor(IMAGE_PATH + "cursor_Skalp_SelectInvert.png", 0, 0) #3
    @cursor_SkalpSubtract_id = UI.create_cursor(IMAGE_PATH + "cursor_Skalp_SelectSubtract.png", 0, 0) #4
    @cursor_SkalpNested_id = UI.create_cursor(IMAGE_PATH + "cursor_Skalp_SelectNested.png", 0, 0) #5

    start_tool
  end

  def resume(view)
    start_tool
  end

  def start_tool
    Skalp.skalpTool_active = true
    set_status_text
    @faces = []

    @sectiongroup = Sketchup.active_model.selection.first if Sketchup.active_model.selection.first && Sketchup.active_model.selection.first.get_attribute('Skalp', 'ID')

    if @sectiongroup
      @id = @sectiongroup.get_attribute('Skalp', 'ID')
    elsif @id
      get_sectiongroup
    else
      Sketchup.active_model.select_tool(nil)
    end

    Sketchup.active_model.selection.clear
  end

  def onSetCursor
    case @cursor_type
    when 0
      UI.set_cursor(@cursor_SU_id)
    when 1
      UI.set_cursor(@cursor_Skalp_id)
    when 2
      UI.set_cursor(@cursor_SkalpAdd_id)
    when 3
      UI.set_cursor(@cursor_SkalpInvert_id)
    when 4
      UI.set_cursor(@cursor_SkalpSubtract_id)
    when 5
      UI.set_cursor(@cursor_SkalpNested_id)
    end
    @view.refresh if @view
  end

  def add_node_to_selection(node)
    entity = node.skpEntity
    if entity.is_a?(Sketchup::Model)
      for e in Sketchup.active_model.entities
        Sketchup.active_model.selection.add(e) if e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Edge)
      end
    else
      if node.parent.value.skpEntity.is_a?(Sketchup::Model)
        Sketchup.active_model.selection.add(entity)
      else
        Sketchup.active_model.selection.add(entity)
      end
    end
  end

  def remove_node_to_selection(node)
    entity = node.skpEntity
    if entity.is_a?(Sketchup::Model)
      for e in Sketchup.active_model.entities
        Sketchup.active_model.selection.remove(e) if e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Edge)
      end
    else
      Sketchup.active_model.selection.remove(entity)
    end
  end

  def onLButtonDown(flags, x, y, view)
    Skalp.active_model.observer_active = false

    ph = view.pick_helper
    ph.do_pick(x, y)

    face = ph.picked_face

    case Skalp.key(flags)
    when :no_key #no keys
      if face_from_section?(face)
        node = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_object')]
        @selected_objects = [node]
        @selected_section_faces = find_faces(face)
        Sketchup.active_model.selection.clear
        add_node_to_selection(node)
        Skalp.dialog.update
      end

    when :alt #Alt  (Add)
      if face_from_section?(face)
        node = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_object')]
        @selected_objects += [node]
        @selected_section_faces += find_faces(face)
        add_node_to_selection(node)
        Skalp.dialog.update
      end

    when :shift #Shift (Invert)
      if face_from_section?(face)
        node = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_object')]
        if @selected_objects.include?(node)
          @selected_objects -= [node]
          remove_node_to_selection(node)
        else
          @selected_objects += [node]
          add_node_to_selection(node)
        end

        for found_face in find_faces(face)
          if @selected_section_faces.include?(found_face)
            @selected_section_faces -= [found_face]
          else
            @selected_section_faces += [found_face]
          end
        end

        Skalp.dialog.update
      end

    when :command
      if face_from_section?(face)
        node = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_sub_object')]

        if @selected_objects.include?(node)
          @selected_objects -= [node]
          remove_node_to_selection(node)
        else
          @selected_objects += [node]
          add_node_to_selection(node)
        end

        for found_face in find_faces(face, true)
          if @selected_section_faces.include?(found_face)
            @selected_section_faces -= [found_face]
          else
            @selected_section_faces += [found_face]
          end
        end

        Skalp.dialog.update
      end

    when :shift_alt # Shift + Alt (Subtract)
      if face_from_section?(face)
        node = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_object')]
        entity = node.skpEntity
        @selected_objects -= [node]
        @selected_section_faces -= find_faces(face)
        Sketchup.active_model.selection.remove(entity)
        Skalp.dialog.update
      end
    end

    if face == nil
      Sketchup.active_model.select_tool(nil)
    elsif face.get_attribute('Skalp', 'from_object') == '' || face.get_attribute('Skalp', 'from_object') == nil
      ph = view.pick_helper
      ph.do_pick(x, y)
      selected = ph.best_picked
      Sketchup.active_model.selection.clear
      Sketchup.active_model.selection.add(selected)
      Sketchup.active_model.select_tool(nil)
    end

    Skalp.active_model.observer_active = true
  end

  def find_faces(selected_face, sub_object = false)
    faces = []
    for face in @sectiongroup.entities.grep(Sketchup::Face)
      if sub_object
        faces << face if face.get_attribute('Skalp', 'from_sub_object') == selected_face.get_attribute('Skalp', 'from_sub_object')
      else
        faces << face if face.get_attribute('Skalp', 'from_object') == selected_face.get_attribute('Skalp', 'from_object')
      end

    end
    return faces
  end

  def onKeyDown(key, repeat, flags, view)
    key_status(key, flags, :down)
  end

  def onKeyUp(key, repeat, flags, view)
    key_status(key, flags, :up)
  end

  def key_status(key, flags=0, status=:no_status)
    set_status_text
    unless @cursor_type == 0
      case Skalp.key(flags, key, status)
      when :shift_alt # Shift + Alt (Subtract)
        @cursor_type = 4
      when :alt #Alt  (Add)
        @cursor_type = 2
      when :shift #Shift (Invert)
        @cursor_type = 3
      when :command #cmd
        @cursor_type = 5
      when :no_key
        @cursor_type = 1
      end
    end
    onSetCursor
  end

  def onMouseMove(flags, x, y, view)
    @view = view
    @view.refresh
    set_status_text

    ph = view.pick_helper
    ph.do_pick(x, y)
    face = ph.picked_face

    if face_from_section?(face)
      if @cursor_type == 0
        @cursor_type = 1
        key_status(flags)
      end

      if Skalp.key(flags) == :command
        node_value = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_sub_object')]
        @temp_selected_faces = find_faces(face, true)
      else
        node_value = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_object')]
        @temp_selected_faces = find_faces(face)
      end

      @temp_selected_objects = [node_value]

    else
      @cursor_type = 0
      onSetCursor
      @temp_selected_faces = []
      @temp_selected_objects = []
    end
  end

  def set_status_text
    info_text = 'Alt = add to selection. Shift = invert selection. Shift+Alt = deselect form selection. Command = select inside group/component'
    Sketchup.set_status_text info_text, SB_PROMPT
  end

  def get_sectiongroup
    return unless @id
    for group in Sketchup.active_model.entities.grep(Sketchup::Group)
      @sectiongroup = group if group.get_attribute('Skalp', 'ID') == @id
    end
    find_faces_from_selected_objects
  end

  def find_faces_from_selected_objects
    @selected_section_faces = []
    for object in @selected_objects
      for face in @sectiongroup.entities.grep(Sketchup::Face)
        node = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_object')]
        @selected_section_faces << face if node == object
      end
    end
  end

  def draw(view)
    get_sectiongroup if @sectiongroup.deleted?
    return if @sectiongroup.deleted?
    t = @sectiongroup.transformation


    view.drawing_color = [255, 0, 0] #[205,51,50]
    view.line_width = 5
    faces = @selected_section_faces + @temp_selected_faces
    for face in faces
      if face && face.valid?
        for edge in face.edges
          next if edge.hidden?
          pt1 = t * edge.start.position
          pt2 = t * edge.end.position

          view.draw_line pt1, pt2
        end
      end
    end

    view.drawing_color = [255, 0, 0, 0.75] #[205,51,50,0.75]
    view.line_width = 0
    for face in @selected_section_faces
      if face && face.valid?
        mesh = face.mesh.transform!(t)
        for polygon in mesh.polygons
          points = polygon.map { |pointindex| mesh.point_at(pointindex.abs) }
          view.draw GL_POLYGON, points
        end
      end
    end

    view.drawing_color = [255, 0, 0, 0.30] #[205,51,50,0.30]
    view.line_width = 0
    for face in @temp_selected_faces
      if face && face.valid?
        mesh = face.mesh.transform!(t)
        for polygon in mesh.polygons
          points = polygon.map { |pointindex| mesh.point_at(pointindex.abs) }
          view.draw GL_POLYGON, points
        end
      end
    end

    camera = view.camera

    if camera.perspective? || (Skalp.active_model.active_sectionplane && camera.direction.samedirection?(Skalp.active_model.active_sectionplane.normal)) == false
      objects = @selected_objects
      for object in objects
        if object.skpEntity && object.skpEntity.valid?
          view.drawing_color = [130, 0, 0, 0.75] #[205,51,50]
          view.line_width = 1
          view.line_stipple = "_"
          for face in Skalp.get_definition_entities(object.skpEntity).grep(Sketchup::Face)
            for loop in face.loops
              points=[]
              for point in loop.vertices
                points << object.transformation * point.position
              end
              view.draw_polyline points
            end
          end
        end
      end
    end
  end

  def suspend(view)
    view.refresh
  end

  def resume(view)
    view.refresh
  end

  def deactivate(view)
    if Skalp.active_model
      Skalp.active_model.observer_active = true
      Skalp.skalpTool_active = false
      view.refresh
      Skalp.dialog.update
    end
  end

  def face_from_section?(face)
    return false unless face.is_a?(Sketchup::Face)
    for face_in_section in @sectiongroup.entities.grep(Sketchup::Face)
      return true if face_in_section == face
    end
    return false
  end
end

@selectTool = SkalpSelect.new
