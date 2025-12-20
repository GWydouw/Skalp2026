def get_material(solid)
  solid.definition.entities.grep(Sketchup::Face).each do |e|
    mat = e.material
    return mat if mat
  end

  solid.definition.entities.grep(Sketchup::Face).each do |e|
    mat = e.back_material
    return mat if mat
  end

  return Sketchup.active_model.materials[0]
end

def clean_solid(solid)
  material = get_material(solid)
  solid.definition.entities.grep(Sketchup::Face).each do |e|
    e.material = nil
    e.back_material = nil
  end
  solid.material = material

  layer = material.name
  su_layer = Sketchup.active_model.layers[layer]
  unless su_layer
    Sketchup.active_model.layers.add(layer)
  end
  solid.layer = material.name
end


def clean_machielsen
  Sketchup.active_model.entities.each do |e|
    if e.class == Sketchup::ComponentInstance
      clean_solid(e)
    end
  end
end

def volume
  selection = Sketchup.active_model.selection
  volume = 0.0
  selection.grep(Sketchup::ComponentInstance).each {|e| volume += e.volume}
  selection.grep(Sketchup::Group).each {|e| volume += e.volume}
  volume = ((volume *0.0254 * 0.0254 * 0.0254) * 1000).to_i.to_f / 1000
  puts "Total volume: #{volume} m3"
end


def select_kepers
  kepers = []
  selection = Sketchup.active_model.selection
  selection.grep(Sketchup::ComponentInstance).each do |e|
    dim = []
    dim << e.bounds.depth
    dim << e.bounds.height
    dim << e.bounds.width
    dim.sort!
    kepers << e if dim[0] == 4.5.cm && dim[1] == 4.5.cm
  end

  Sketchup.active_model.selection.clear
  kepers.each do |e|
    Sketchup.active_model.selection.add(e)
  end
end