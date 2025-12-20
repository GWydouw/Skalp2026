module Skalp
  def scene2image(w = 1600, h = 900, antialias = true, compression = 0.9, transparent = false, img_type = 'jpg')
    model = Sketchup.active_model
    page = model.pages.selected_page
    view = model.active_view
    path = model.path.gsub('.skp', '')
    filename = path + ' - ' + page.name + '.' + img_type
    keys = {
        :filename => filename,
        :width => w,
        :height => h,
        :antialias => antialias,
        :compression => compression,
        :transparent => transparent
    }
    view.write_image(keys)
  end

  def scenes2images
    return unless Sketchup.active_model.pages

    result = UI.inputbox(["scenes", "type", "width", "height", "antialias", "compression", "transparent"], ["Skalp scenes", "jpg", 1600, 900, 'true', '0.9', 'false'],
                         ["Skalp scenes|all scenes|active scene", "jpg|png|tif","", "", "true|false", "0.1|0.2|0.3|0.4|0.5|0.6|0.7|0.8|0.9|1.0", "true|false"], 'Export Scenes to Images')
    if result
      scenes = result[0].to_s
      type = result[1].to_s
      w = result[2].to_i
      h = result[3].to_i
      antialias = result[4] == 'true'
      compression = result[5].to_f
      transparent = result[6] == 'true'

      case scenes
        when "Skalp scenes"
          return unless Skalp.active_model
          Sketchup.active_model.pages.each do |page|
            Sketchup.active_model.pages.selected_page = page
            scene2image(w, h, antialias, compression, transparent, type) if Skalp.active_model.get_memory_attribute(page, 'Skalp', 'ID')
          end
        when "all scenes"
          Sketchup.active_model.pages.each do |page|
            Sketchup.active_model.pages.selected_page = page
            scene2image(w, h, antialias, compression, transparent, type)
          end
        when "active scene"
          scene2image(w, h, antialias, compression, transparent, type)
      end
    end
  end
end
