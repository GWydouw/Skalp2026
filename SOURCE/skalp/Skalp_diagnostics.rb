module Skalp
  def self.diagnose
    model = Sketchup.active_model
    view = model.active_view
    puts "=== SKALP DIAGNOSTICS ==="
    puts "Timestamp: #{Time.now}"
    puts "Model: #{model.title} (#{model.path})"
    puts "Active Page: #{model.pages.selected_page ? model.pages.selected_page.name : 'None'}"
    puts "Active Layer (Tag): #{model.active_layer.name}"
    
    puts "\n--- SECTION PLANE STATUS ---"
    sp_active = Skalp.sectionplane_active
    puts "Skalp.sectionplane_active: #{sp_active}"
    
    active_sp = Skalp.active_model.active_sectionplane
    if active_sp
      puts "Active Skalp SectionPlane: #{active_sp}"
      puts "  Use main? #{active_sp.use_main}"
      puts "  Use rear? #{active_sp.use_rear}"
      puts "  Rearview Status (Style): #{Skalp.dialog.style_settings(model)[:rearview_status] rescue 'Error reading style settings'}"
    else
      puts "No active Skalp SectionPlane"
    end

    puts "\n--- SKALP FOLDERS VISIBILITY ---"
    folders = ['Skalp', 'Skalp Pattern Layers', 'Rear View Lines']
    folders.each do |fname|
      # Try to find folder by name (SketchUp 2024+)
      found = false
      if model.layers.respond_to?(:folders)
         model.layers.folders.each do |f|
            if f.name == fname
               puts "Folder '#{fname}': Visible=#{f.visible?}"
               found = true
               # print sub-layers
               f.layers.each { |l| puts "  - Layer '#{l.name}': Visible=#{l.visible?} (Page Visible: #{model.pages.selected_page ? model.pages.selected_page.layers.include?(l) || l.visible? : l.visible?})" }
               f.folders.each { |subf| puts "  - SubFolder '#{subf.name}': Visible=#{subf.visible?}" }
            end
         end
      end
      puts "Folder '#{fname}' NOT FOUND in root" unless found
    end

    puts "\n--- SECTION RESULT GROUP CONTENTS ---"
    if Skalp.active_model && Skalp.active_model.section_result_group
      srg = Skalp.active_model.section_result_group
      puts "Section Result Group found: #{srg} (Hidden: #{srg.hidden?}, Layer: #{srg.layer.name})"
      
      srg.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        name = e.name.empty? ? "(no name)" : e.name
        skalp_id = e.get_attribute('Skalp', 'ID')
        scenedata = e.get_attribute('Skalp', 'scenedata')
        
        type = e.is_a?(Sketchup::Group) ? "Group" : "CompInst"
        puts "  > #{type}: '#{name}' | ID: #{skalp_id} | Scenedata: #{scenedata ? 'YES' : 'NO'}"
        puts "    Hidden: #{e.hidden?} | Layer: #{e.layer.name} | Visible: #{e.visible?}"
        
        if e.respond_to?(:definition)
           puts "    Definition: #{e.definition.name}"
        end
      end
    else
      puts "Section Result Group NOT FOUND"
    end
    
    puts "\n--- TEST CREATE THUMBNAIL (Proxy) ---"
    # Basic dummy test
    begin
       Skalp.create_thumbnail({:name => "TEST", :pattern => "ANSI31", :png_blob => nil})
       puts "Skalp.create_thumbnail exists and ran (check log for output)"
    rescue => e
       puts "Skalp.create_thumbnail FAILED: #{e.message}"
    end
    
    puts "========================="
    nil
  end
end
puts "Skalp Diagnostic loaded. Run `Skalp.diagnose` in Ruby Console."
