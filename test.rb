Hiddenline_layers = Struct.new(:layer, :name, :original_color, :index_color, :linestyle)

def num2color(num)
  if num < 255
    Sketchup::Color.new(num, 0, 0)
  elsif (num>255 && num<=510)
    Sketchup::Color.new(255, num-255, 0)
  elsif (num>510 && num<=765)
    Sketchup::Color.new(255, 255, num-510)
  else
    Sketchup::Color.new(255,255,255)
  end
end

def color2num(color)
  color.red + color.green + color.blue
end

def setup_layers
  @hiddenline_layer_setup = {}

  i = 0
  Sketchup.active_model.layers.each do |layer|
    next unless layer
    next if layer.get_attribute('Skalp', 'ID')
    layer_setup = Hiddenline_layers.new
    layer_setup.layer = layer
    layer_setup.name = layer.name
    layer_setup.original_color = layer.color

    layer.color = num2color(i)
    i+=1

    layer_setup.index_color = color2num(layer.color)
    layer_setup.linestyle = layer.line_style.name  if layer.line_style
    @hiddenline_layer_setup[layer] = layer_setup
  end
end

def restore_layers
  Sketchup.active_model.layers.each do |layer|
    next if layer.get_attribute('Skalp', 'ID')
    layer.color = @hiddenline_layer_setup[layer].original_color
  end
end



def materials_to_layers
  Sketchup.active_model.entities.grep(Sketchup::ComponentInstance) do |comp|
    material_name = comp.material.name
    unless Sketchup.active_model.layers[material_name]
      Sketchup.active_model.layers.add(material_name)
    end

    comp.layer = material_name
  end
end


def nested_component?(component)
  face = false
  nested_component = false
  component.definition.entities.each do |e|
    face = true if e.class == Sketchup::Face
    nested_component = true if e.class == Sketchup::ComponentInstance
  end

  if face == false and nested_component == true
    return true
  else
    false
  end
end

def explode_nested_components
  explode_components = true

  while explode_components
    nested_components = []
    explode_components = false
    Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).each do |comp|
     nested_components << comp if nested_component?(comp)
    end

    nested_components.each do |comp|
      comp.explode
      explode_components = true
    end
  end
end

def clean_ifc
  Sketchup.active_model.start_operation('clean ifc', true)
  explode_nested_components
  materials_to_layers
  Sketchup.active_model.commit_operation
end


def convert_dxf
  require 'shellwords'
 #  system('open -a safari https://extensions.sketchup.com/en/developer_center/extension_signature')
  source = Shellwords.escape("/Users/guy/Library/Application\ Support/SketchUp\ 2016/SketchUp/Plugins/Skalp_Skalp/Converter/input/")
  target = Shellwords.escape("/Users/guy/Library/Application\ Support/SketchUp\ 2016/SketchUp/Plugins/Skalp_Skalp/Converter/output/")
  output_version = "ACAD2010"
  output_type = "DWG"
  recursive = "0"
  audit = "1"
  filter = "test.dxf"


  app = Shellwords.escape(Skalp::SKALP_PATH + "TeighaFileConverter.app/Contents/MacOS/TeighaFileConverter") # '#{source}' '#{target}' '#{output_version}' '#{output_type}' '#{recursive}' '#{audit}'")
  command = %Q(#{app} "#{source}" "#{targert}" "#{output_version}" "#{output_type}" "#{recursive}" "#{audit}" "#{filter}")
  puts command
  system(command)
end


entities = Sketchup.active_model.entities
Sketchup.active_model.definitions.each { |d| $skalp_def = d if d.name == 'test'}
$skalp_def.entities.add_cpoint(Geom::Point3d.new(0,0,0))



entities = Sketchup.active_model.entities
Sketchup.active_model.definitions.each { |d| puts d.name}
for n in 0..100 do
  $skalp_def.entities.add_cpoint(Geom::Point3d.new(n*10,n*20,n*30))
end
$skalp_def.entities.add_cpoint(Geom::Point3d.new(0,0,0))


class OpenGL
  def activate
    Sketchup.active_model.active_view.invalidate
  end

  def draw(view)
    # Draw a square.
    points = [
        Geom::Point3d.new(0, 0, 0),
        Geom::Point3d.new(9, 0, 0),
        Geom::Point3d.new(9, 9, 0),
        Geom::Point3d.new(0, 9, 0)
    ]
    # Fill
    view.drawing_color = Sketchup::Color.new(255, 128, 128)
    view.draw(GL_QUADS, points)
    # Outline
    view.line_stipple = '' # Solid line
    view.drawing_color = Sketchup::Color.new(64, 0, 0)
    view.draw(GL_LINE_LOOP, points)
  end
end

$opengl = OpenGL.new

active_tool

class MyEntitiesObserver < Sketchup::EntitiesObserver
  def onElementAdded(entities, entity)
    UI.start_timer(0.0, false) {Sketchup.active_model.select_tool($opengl)}
  end

  def onElementModified(entities, entity)
    UI.start_timer(0.0, false) {Sketchup.active_model.select_tool($opengl)}
  end

  def onElementRemoved(entities, entity_id)
    UI.start_timer(0.0, false) {Sketchup.active_model.select_tool($opengl)}
  end
end

Sketchup.active_model.entities.add_observer(MyEntitiesObserver.new)

class MyViewObserver < Sketchup::ViewObserver
  def onViewChanged(view)
    UI.start_timer(0.0, false) {Sketchup.active_model.select_tool($opengl)}
  end
end

# Attach the observer.
Sketchup.active_model.active_view.add_observer(MyViewObserver.new)

module Enscape
  class LayerHelperClass
    def self.check_layer_zero(layer)
      begin
        layer <=> nil
      rescue
        -1
      end
    end
  end
end

Sketchup.active_model.layers['Layer0'].visible=false
Sketchup.active_model.layers['Layer0'].visible=true

Sketchup.active_model.layers.add('temp')
Sketchup.active_model.layers.remove('temp')


def randomkleur
  model = Sketchup.active_model
  model.start_operation("randomkleur", true, false, false)
  selection = model.selection
  colors = ['green1', 'green2', 'green3', 'green4', 'geel1', 'geel2', 'geel3']
  selection.first.definition.entities.each do |instance|
    instance.material = colors[rand(4)]
  end
  model.commit_operation
end


def randomdikte
  model = Sketchup.active_model
  model.start_operation("randomkleur", true, false, false)
  selection = model.selection
  t1 = selection.first.transformation
  selection.first.definition.entities.each do |instance|


    t = (t1 * instance.transformation ).to_a
    point = Geom::Point3d.new(t[12], t[13], t[14])
    scale = rand(3) + 1
    tr = Geom::Transformation.scaling(point, 1, scale, 1)
    instance.transform!(tr)
  end
  model.commit_operation
end



def clean
  model = Sketchup.active_model
  materials = model.materials
  to_delete = []
  materials.each do |mat|
    to_delete << mat unless mat.get_attribute('Skalp', 'ID')
  end
  model.start_operation('remove materials', true, false, false)
  to_delete.each do |mat|
    materials.remove(mat)
  end
  model.commit_operation
end

UI::HtmlDialog::STYLE_WINDOW
UI::HtmlDialog::STYLE_DIALOG
UI::HtmlDialog::STYLE_UTILITY

@dialog = UI::HtmlDialog.new(
    {
        :dialog_title => "Dialog Example",
        :preferences_key => "com.sample.plugin",
        :scrollable => true,
        :resizable => true,
        :width => 600,
        :height => 400,
        :left => 100,
        :top => 100,
        :min_width => 50,
        :min_height => 50,
        :max_width =>1000,
        :max_height => 1000,
        :style => UI::HtmlDialog::STYLE_DIALOG
    })
@dialog.set_url("http://www.sketchup.com")
@dialog.show


#visibility of the section result group

def full_show_page2(entities, page)
  entities.grep(Sketchup::Drawingelement) do |e|
    page.set_drawingelement_visibility(e, true)
    pp "TRUE2 #{e}: #{page.get_drawingelement_visibility(e)}"
    full_show_page(e.entities, page) if e.class == Sketchup::Group
  end
end

def manage
  page = Sketchup.active_model.pages.selected_page
  Skalp.active_model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
    if section_group.get_attribute('Skalp', 'ID') == page.get_attribute('Skalp', 'ID')
      page.set_drawingelement_visibility(section_group, true)
      pp "TRUE1 #{section_group.name}: #{page.get_drawingelement_visibility(section_group)}"
      full_show_page2(section_group.entities, page)
    else
      page.set_drawingelement_visibility(section_group, false)
      pp "FALSE1 #{section_group.name}: #{page.get_drawingelement_visibility(section_group)}"
    end
  end
end

def hide_all
  page = Sketchup.active_model.pages.selected_page
  group= Sketchup.active_model.entities.grep(Sketchup::Group).first
  group.entities.each do |e|
    page.set_drawingelement_visibility(e, false)
  end
end

def show_all
  page = Sketchup.active_model.pages.selected_page
  group= Sketchup.active_model.entities.grep(Sketchup::Group).first
  group.entities.each do |e|
    page.set_drawingelement_visibility(e, true)
  end
end

def read_all
  page = Sketchup.active_model.pages.selected_page
  group= Sketchup.active_model.entities.grep(Sketchup::Group).first
  group.entities.each do |e|
    pp "#{e} - visibility:#{page.get_drawingelement_visibility(e)}"
  end
end