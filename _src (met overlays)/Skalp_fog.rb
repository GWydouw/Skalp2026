module Skalp
  def reverse_view
    view = Sketchup.active_model.active_view
    active_camera = view.camera

    my_camera = Sketchup::Camera.new active_camera.target, active_camera.eye, active_camera.up
    my_camera.perspective = active_camera.perspective?

    if active_camera.perspective?
      my_camera.fov = active_camera.fov
      my_camera.focal_length = active_camera.focal_length
    else
      my_camera.height = active_camera.height
    end

    view.camera = my_camera
  end

  def align_view(skpSectionPlane, perspective=nil)
    return unless skpSectionPlane
    view = Sketchup.active_model.active_view
    active_camera = view.camera

    plane = skpSectionPlane.get_plane
    target = [plane[0], plane[1], plane[2]]
    eye = [0.0, 0.0, 0.0]

    up = get_up_vector(plane)
    my_camera = Sketchup::Camera.new eye, target, up

    if (active_camera.eye - active_camera.target).samedirection?(my_camera.eye - my_camera.target)
      my_camera.perspective = !view.camera.perspective?
    else
      my_camera.perspective = view.camera.perspective?
    end

    # Get a handle to the current view and change its camera.
    view.camera = my_camera
    view.zoom_extents
  end

  def fog
    model = Sketchup.active_model

    return unless model.entities.active_section_plane

    plane = model.entities.active_section_plane.get_plane
    direction = model.active_view.camera.direction
    active_page = model.pages.selected_page

    unless direction.parallel?(plane[0..2])
      result = UI.messagebox(Skalp.translate('Skalp will Align your view with the Section Plane.'), MB_OKCANCEL)

      if result == 2
        Skalp.dialog.fog_status_switch_off
        return
      else
        align_view(model.entities.active_section_plane)
      end
    end

    set_fog_rendering_options(model)

    if Skalp.dialog.save_settings_status
      set_fog_rendering_options(active_page)
    end

    unless Skalp.active_model.view_observer
      Skalp.active_model.view_observer = SkalpViewObserver.new
      Sketchup.active_model.active_view.add_observer(Skalp.active_model.view_observer)
    end
  end

  def get_section_distance
    model = Sketchup.active_model
    plane = model.entities.active_section_plane.get_plane
    camera = model.active_view.camera.eye
    camera.project_to_plane(plane).distance(camera)
  end

  def set_fog_rendering_options(object = Sketchup.active_model)
    tolerance = Sketchup.read_default('Skalp', 'tolerance2').to_f

    section_distance = get_section_distance
    rendering_options = rendering_options?(object).rendering_options
    rendering_options['DisplayFog'] = true

    rendering_options['FogStartDist'] = section_distance
    rendering_options['FogEndDist'] = section_distance + (tolerance * 2) + Skalp.dialog.fog_distance.to_inch
  end
end