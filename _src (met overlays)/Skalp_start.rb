module Skalp
  def self.run_skalp
    @log.info("start Skalp")

    require 'Skalp_Skalp/Skalp_geom2.rb'
    require 'Skalp_Skalp/Skalp_lib2.rb'
    require 'Skalp_Skalp/Skalp_API.rb'

    sketchup_set_class_repair
    eval("class Skalp::Set < Object::Set; end") rescue nil #fails on second run: \
    # Error: #<TypeError: superclass mismatch for class Set> \
    # http://stackoverflow.com/questions/9814282/typeerror-superclass-mismatch-for-class-word-ruby

    skalp_require_hatch_lib
    skalp_require_hatchtile
    skalp_require_hatch_class
    skalp_require_hatchdefinition_class
    skalp_require_hatchline_class
    skalp_require_hatchpatterns_main

    require 'Matrix'
    Sketchup::require "Skalp_Skalp/chunky_png/lib/chunky_png"

    skalp_requires
    skalp_require_isolate unless defined?(Skalp::Isolate)

    if @hatch_dialog == nil && @webdialog_require == false
      skalp_require_dialog # Sketchup::require 'Skalp/skalp_webdialog'  #
      @webdialog_require = true
    end

    Dir.chdir(SU_USER_PATH)

    @page_change = false
    @unloaded = false
    @dxf_export = false
    @tool_changed = false
    @live_section_ON = true

    Skalp.convert_old_libraries_to_json

    @models = {}

    @model_collection << Sketchup.active_model unless @model_collection.include?(Sketchup.active_model)

    for model in @model_collection.uniq.compact
      activate_model(model) if model.valid?
    end

    @active_model = @models[Sketchup.active_model]
    @dialog = Sections_dialog.new
    @status = 1
    @active_model.load = true
  end


  def self.num
    guid == Sketchup.read_default('Skalp', 'guid') ? 1 : 0
  end
end
