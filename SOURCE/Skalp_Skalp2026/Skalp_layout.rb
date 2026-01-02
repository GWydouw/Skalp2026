module Skalp
  def self.create_layout_scrapbook
    unless defined?(Layout)
      UI.messagebox("This feature requires SketchUp Pro with Layout API support.")
      return
    end

    model = Sketchup.active_model
    original_path = model.path
    if original_path.empty?
      UI.messagebox("Please save the model first.")
      return
    end

    # Check for Skalp scenes
    skalp_scenes = model.pages.select { |p| p.get_attribute("Skalp", "ID") }

    if skalp_scenes.empty?
      # Fallback
      skalp_scenes = model.pages.select { |p| p.attribute_dictionary("Skalp") }
    end

    if skalp_scenes.empty?
      UI.messagebox("No Skalp scenes found in this model.")
      return
    end

    # Ask user for confirmation
    result = UI.messagebox(
      "This will create a LayOut Scrapbook from the current model's Skalp scenes.\n\nA sidecar model '_skalp_layout_source.skp' will be created.\nProceed?", MB_OKCANCEL
    )
    return unless result == IDOK

    start_time = Time.now
    Sketchup.status_text = "Preparing Scrapbook Export..."

    # Define paths
    dir = File.dirname(original_path)
    base = File.basename(original_path, ".*")
    source_skp_name = "#{base}_skalp_layout_source.skp"
    source_skp_path = File.join(dir, source_skp_name)

    # Output LayOut path
    scrapbooks_dir = File.join(ENV.fetch("HOME", nil), "Library/Application Support/SketchUp 2026/LayOut/Scrapbooks")
    FileUtils.mkdir_p(scrapbooks_dir) unless File.exist?(scrapbooks_dir)

    doc_name = "Skalp Exported Sections.layout"
    doc_path = File.join(scrapbooks_dir, doc_name)

    # Ensure we overwrite by deleting the existing file first
    # This also prevents LayOut from creating "Backup of..." files
    backup_name = "Backup of #{doc_name}"
    backup_path = File.join(scrapbooks_dir, backup_name)

    [doc_path, backup_path].each do |p|
      next unless File.exist?(p)

      begin
        File.delete(p)
      rescue StandardError => e
        puts "Could not delete existing file #{p}: #{e.message}"
      end
    end

    begin
      # 1. Save clean copy of current model to sidecar path
      model.save_copy(source_skp_path)

      Sketchup.status_text = "Generating LayOut file via Skalp Engine..."
      puts "Calling C++ Engine: input=#{source_skp_path} output=#{doc_path}"

      # 2. Call C++ API
      success = Skalp.create_layout_scrapbook_C_API(source_skp_path, doc_path)

      if success
        elapsed = Time.now - start_time
        Sketchup.status_text = "Scrapbook created in #{elapsed.round(2)}s."
        UI.messagebox("Scrapbook created successfully!\n\nFile saved to:\n#{doc_path}")
      else
        Sketchup.status_text = "Scrapbook creation failed."
        UI.messagebox("Error: The Skalp Engine failed to generate the scrapbook.\nCheck console for details.")
      end
    rescue StandardError => e
      UI.messagebox("Error creating scrapbook: #{e.message}")
      puts e.backtrace
    ensure
      Sketchup.status_text = ""
    end
  end
end
