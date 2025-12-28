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

  def align_view(skpSectionPlane, perspective = nil)
    return unless skpSectionPlane

    view = Sketchup.active_model.active_view
    active_camera = view.camera

    plane = skpSectionPlane.get_plane
    target = [plane[0], plane[1], plane[2]]
    eye = [0.0, 0.0, 0.0]

    up = get_up_vector(plane)
    my_camera = Sketchup::Camera.new eye, target, up

    my_camera.perspective = if (active_camera.eye - active_camera.target).samedirection?(my_camera.eye - my_camera.target)
                              !view.camera.perspective?
                            else
                              view.camera.perspective?
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
      result = UI.messagebox(Skalp.translate("Skalp will Align your view with the Section Plane."), MB_OKCANCEL)

      if result == 2
        Skalp.dialog.fog_status_switch_off
        return
      else
        align_view(model.entities.active_section_plane)
      end
    end

    set_fog_rendering_options(model)

    set_fog_rendering_options(active_page) if Skalp.dialog.save_settings_status

    return if Skalp.active_model.view_observer

    Skalp.active_model.view_observer = SkalpViewObserver.new
    Sketchup.active_model.active_view.add_observer(Skalp.active_model.view_observer)
  end

  def get_section_distance
    model = Sketchup.active_model
    plane = model.entities.active_section_plane.get_plane
    camera = model.active_view.camera.eye
    camera.project_to_plane(plane).distance(camera)
  end

  def set_fog_rendering_options(object = Sketchup.active_model)
    tolerance = Sketchup.read_default("Skalp", "tolerance2").to_f

    section_distance = get_section_distance

    # Page doesn't have rendering_options method, it should always be model
    ro_container = if object.is_a?(Sketchup::Model)
                     object
                   else
                     Sketchup.active_model
                   end

    rendering_options = ro_container.rendering_options
    rendering_options["DisplayFog"] = true

    # Debug: trace where fog_distance comes from
    raw_fog_dist = Skalp.dialog.fog_distance(object)
    puts "=" * 60
    puts "Skalp Fog Debug: Fog Distance Trace"
    puts "  object: #{object.is_a?(Sketchup::Page) ? object.name : 'Model'}"
    puts "  raw fog_distance value: #{raw_fog_dist.inspect}"
    puts "  raw fog_distance class: #{raw_fog_dist.class}"

    # Also check style_settings directly
    if Skalp.dialog.respond_to?(:style_settings)
      settings = Skalp.dialog.style_settings(object)
      puts "  style_settings[:depth_clipping_distance]: #{settings[:depth_clipping_distance].inspect}"
    end
    puts "=" * 60

    fog_dist_val = if raw_fog_dist.nil?
                     0.0
                   elsif raw_fog_dist.respond_to?(:to_inch)
                     raw_fog_dist.to_inch
                   else
                     raw_fog_dist.to_f
                   end

    rendering_options["FogStartDist"] = section_distance
    rendering_options["FogEndDist"] = section_distance + (tolerance * 2) + fog_dist_val

    puts "Skalp Fog Debug: dist=#{section_distance}, fog_dist=#{fog_dist_val}, end=#{rendering_options['FogEndDist']}"

    # If it's a page, we need to update the page to save these rendering options
    return unless object.is_a?(Sketchup::Page) && object.use_rendering_options?

    object.update(16) # 16 = Drawing Style (which includes rendering options)
  end
end
