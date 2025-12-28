module Skalp
  class SkalpEntitiesObserver < Sketchup::EntitiesObserver
    @@watched_types = [Sketchup::ComponentInstance, Sketchup::Group, Sketchup::Face, Sketchup::SectionPlane]

    def watched_types
      @@watched_types
    end

    def onElementModified(entities, entity)
      return unless entity.valid?

      if Skalp.observer_check == true
        Skalp.observer_check_result = true
        Skalp.observer_check = false
        return
      end
      return if Skalp.status == 0

      if entity.class == Sketchup::LayerFolder
        data = {
          action: :changed_layer,
          layer: ""
        }
        Skalp.models[entity.model].controlCenter.add_to_queue(data)
      end

      if entity.is_a?(Sketchup::SectionPlane)
        id = entity.get_attribute("Skalp", "ID")

        if Skalp.new_sectionplane == entity && [nil,
                                                ""].include?(id) && entity.name && entity.name != "" && entity.symbol && entity.symbol != ""
          Skalp.new_sectionplane = nil

          if @@watched_types.include?(entity.class)
            data = {
              action: :add_element,
              entities: entities,
              entity: entity
            }

            Skalp.models[entities.model].controlCenter.add_to_queue(data)
          end
        else
          return
        end
        # Skalp.active_model.hiddenlines.sectionplane_changed(id)
      end

      return unless Skalp.models[entities.model] && Skalp.models[entities.model].observer_active
      return if entity.is_a?(Sketchup::Group) && entity.get_attribute("Skalp", "ID")

      if @@watched_types.include?(entity.class)
        data = {
          action: :modified_element,
          entities: entities,
          entity: entity
        }
        Skalp.models[entities.model].controlCenter.add_to_queue(data)
      end
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onElementAdded(entities, entity)
      return unless entity.valid?
      return if Skalp.status == 0
      return unless Skalp.models && Skalp.models[entities.model] && Skalp.models[entities.model].observer_active

      return if entity.get_attribute("Skalp", "ID") && entity.get_attribute("Skalp", "sectionplane_name").nil?

      if @@watched_types.include?(entity.class)
        data = {
          action: :add_element,
          entities: entities,
          entity: entity
        }
        Skalp.models[entities.model].controlCenter.add_to_queue(data)
      end
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onElementRemoved(entities, entity_id) # TODO: via de entites de parent van het deleted element opvragen en deze updaten!
      return if Skalp.active_model && Skalp.active_model.sectionplane_entityIDs.include?(entity_id)
      return if Skalp.status == 0
      return unless Skalp.models[entities.model] && Skalp.models[entities.model].observer_active

      Skalp.dialog.model_changed

      parent = entities.parent

      if parent.class == Sketchup::ComponentDefinition && !parent.deleted?
        for inst in parent.instances
          data = {
            action: :modified_element,
            entity: inst
          }
          Skalp.models[entities.model].controlCenter.add_to_queue(data)
        end
      end

      data = {
        action: :removed_element,
        entities: entities,
        entity_id: entity_id
      }
      Skalp.models[entities.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpPagesObserver < Sketchup::PagesObserver
    def onContentsModified(pages)
      return if Skalp.active_model && Skalp.active_model.page_undo
      return if Skalp.status == 0
      return unless Skalp.models[pages.model] && Skalp.models[pages.model].observer_active

      if Skalp.live_section_ON == false
        Sketchup.active_model.rendering_options["SectionDefaultFillColor"] = "DarkGray"
        Sketchup.active_model.rendering_options["SectionCutFilled"] = true
      end

      Skalp.active_model.rename_scene_layer(pages)

      data = {
        action: :modified_pages,
        pages: pages
      }
      Skalp.active_model.controlCenter.add_to_queue(data) if Skalp.active_model && Skalp.active_model.controlCenter
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onElementAdded(pages, page)
      return unless page.valid?
      return if Skalp.status == 0
      return unless Skalp.models[pages.model].observer_active

      data = {
        action: :add_page,
        pages: pages,
        page: page
      }
      Skalp.models[pages.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onElementRemoved(pages, page)
      return unless page.valid?
      return if Skalp.status == 0
      return unless Skalp.models[pages.model].observer_active

      data = {
        action: :removed_page,
        pages: pages,
        page: page
      }
      Skalp.models[pages.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpViewObserver < Sketchup::ViewObserver
    def initialize
      @model = Sketchup.active_model

      @parallel_current_state = parallel(@model.active_view) ? :parallel : :non_parallel
      @last_active_scene = @model.pages.selected_page
      @changed = false
    end

    def onViewChanged(view)
      return if @model.entities.active_section_plane.nil?
      return if Skalp.block_observers

      ps_changed = parallel_state_changed?(view)
      current_page = @model.pages ? @model.pages.selected_page : @model

      if Skalp.dialog.fog_status(current_page)
        if @parallel_current_state == :parallel
          # Update fog distance if camera eye has moved significantly
          if @last_camera_eye.nil? || @last_camera_eye.distance(view.camera.eye) > 0.001
            Skalp.set_fog_rendering_options
            @last_camera_eye = view.camera.eye.clone
          end

          if ps_changed
            Skalp.dialog.align_view_symbol_black
            @model.rendering_options["DisplayFog"] = true
          end
        elsif ps_changed
          Skalp.dialog.align_view_symbol_red
          @model.rendering_options["DisplayFog"] = false
        end
      elsif ps_changed && @parallel_current_state == :non_parallel
        @model.rendering_options["DisplayFog"] = false
      end

      @last_active_scene = Sketchup.active_model.pages.selected_page
    end

    def parallel_state_changed?(view)
      @parallel_current_state = parallel(view) ? :parallel : :non_parallel
      if @parallel_previous_state == @parallel_current_state
        false
      else
        @parallel_previous_state = @parallel_current_state
        true
      end
    end

    def parallel(view)
      plane = @model.entities.active_section_plane.get_plane
      direction = view.camera.direction
      direction.parallel?(plane[0..2])
    end
  end

  class SkalpRenderingOptionsObserver < Sketchup::RenderingOptionsObserver
    def onRenderingOptionsChanged(rendering_options, type)
      return unless Skalp.dialog

      if Skalp.live_section_ON == false
        Sketchup.active_model.rendering_options["SectionCutFilled"] = true
        Sketchup.active_model.rendering_options["SectionDefaultFillColor"] = "DarkGray"
      end

      if type == 1
        return if Skalp.block_observers

        Skalp.dialog.check_SU_style
      else
        Skalp.dialog.check_SU_style
        nil
      end
    end
  end

  class SkalpModelObserver < Sketchup::ModelObserver
    def onPreSaveModel(model)
      return if Skalp.block_observers
      return unless model.valid?

      model.set_attribute("Skalp", "version", SKALP_VERSION[0..2].to_s)
      Skalp.remove_scaled_textures
      Skalp.active_model.force_start("Skalp - #{Skalp.translate('save attributes to model')}")
      Skalp.active_model.memory_attributes.save_to_model
      Skalp.active_model.commit
      Skalp.fixTagFolderBug("PreSaveModel")
    end

    def onTransactionCommit(model)
      return unless model.valid?
      # puts "COMMIT: #{caller_locations(1,1)[0].label}"
      # puts caller
      return unless Skalp.models[model]
      return unless Skalp.models[model].observer_active

      nil if Skalp.models[model].undoredo_action

      # MIGRATION SU2026: Removed pagesUndoRedo.redostack clearing
      # Native undo handles redo stack automatically
    end

    def onTransactionStart(model)
      nil unless model.valid?
      # Skalp.p("!!! TransactionStart #{caller(1,1)}") if operation_check(caller(1,1))
    end

    def operation_check(caller)
      return false if Skalp.active_model.operation > 0
      return false unless caller && caller[0]
      return false if caller[0].include?("start_operation")
      return false if caller[0].include?("commit_operation")

      # return false if caller[0].include?('sketchup/plugins') # start from other plugin
      true
    end

    def onTransactionAbort(model)
      return unless model.valid?
      return if Skalp.status == 0
      return unless Skalp.models[model]
      return unless Skalp.models[model].observer_active

      data = {
        action: :abort_transaction,
        model: model
      }
      Skalp.models[model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onTransactionEmpty(model)
      return unless model.valid?
      # Skalp.p("!!! TransactionEmpty #{caller}")
      return if Skalp.status == 0
      return unless Skalp.models[model]
      return unless Skalp.models[model].observer_active

      data = {
        action: :empty_transaction,
        model: model
      }
      Skalp.models[model].controlCenter.add_to_queue(data)
    end

    # MIGRATION SU2026: Removed custom pagesUndoRedo.undo
    # Native SketchUp undo now handles scene state automatically
    def onTransactionUndo(model)
      return unless model.valid?
      return unless Skalp.models[model]
      return if Skalp.status == 0
      return unless Skalp.models[model].observer_active

      # pagesUndoRedo.undo removed - native undo handles this now
      # But we still need to update the dialog
      Skalp.models[model].pagesUndoRedo.update_dialog if Skalp.models[model].pagesUndoRedo

      paint = if Skalp::Material_dialog.materialdialog
                true
              else
                false
              end

      data = {
        action: :undo_transaction,
        model: model,
        paint_tool: paint
      }

      return unless Skalp.models[model]

      Skalp.models[model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    # MIGRATION SU2026: Removed custom pagesUndoRedo.redo
    # Native SketchUp redo now handles scene state automatically
    def onTransactionRedo(model)
      return unless model.valid?
      return if Skalp.status == 0
      return unless Skalp.models[model]
      return unless Skalp.models[model].observer_active

      # pagesUndoRedo.redo removed - native redo handles this now
      # But we still need to update the dialog
      Skalp.models[model].pagesUndoRedo.update_dialog if Skalp.models[model].pagesUndoRedo

      data = {
        action: :redo_transaction,
        model: model
      }
      Skalp.models[model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onActivePathChanged(model)
      return unless model.valid?
      return if Skalp.status == 0
      return unless Skalp.models[model]
      return unless Skalp.models[model].observer_active

      data = {
        action: :active_path_changed,
        model: model
      }
      Skalp.models[model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpToolsObserver < Sketchup::ToolsObserver
    # @last_used_tool = 21022  #selectiontool
    def onActiveToolChanged(tools, tool_name, tool_id)
      return if Skalp.status == 0
      return unless Skalp.models[Sketchup.active_model]
      return unless Skalp.models[Sketchup.active_model].observer_active

      data = {
        action: :active_tool_changed,
        tools: tools,
        tool_name: tool_name,
        tool_id: tool_id
      }
      Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onToolStateChanged(tools, tool_name, tool_id, tool_state)
      return if Skalp.status == 0
      return unless Sketchup.active_model && Skalp.models[Sketchup.active_model]
      return unless Skalp.models[Sketchup.active_model].observer_active

      data = {
        action: :tool_state_changed,
        tools: tools,
        tool_name: tool_name,
        tool_id: tool_id,
        tool_state: tool_state
      }
      Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpEntityObserver < Sketchup::EntityObserver
    def onChangeEntity(entity)
      return unless entity.is_a?(Sketchup::Entity)
      return unless entity.valid?
      return if Skalp.status == 0
      return unless Skalp.models[entity.model] && Skalp.models[entity.model].observer_active
      return unless entity.class == Sketchup::SectionPlane

      data = {
        action: :change_sectionplane,
        entity: entity
      }
      Skalp.models[entity.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onEraseEntity(entity)
      return unless entity.class == Sketchup::SectionPlane
      return if Skalp.status == 0
      return unless Skalp.models[Sketchup.active_model].observer_active

      data = {
        action: :erase_sectionplane,
        entity: entity
      }
      Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpLicenseObserver < Sketchup::AppObserver
    def onQuit
      if Sketchup.read_default("Skalp",
                               "guid") && File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic") && Skalp.check_license_type_on_server(Sketchup.read_default(
                                                                                                                                                                    "Skalp", "guid"
                                                                                                                                                                  )) == "network"
        Skalp.auto_deactivate(Sketchup.read_default("Skalp", "guid"), false)
      end
      Skalp.check_license_type_on_server(Sketchup.read_default("Skalp", "guid")) # extra command to ensure the auto_deactivate works  (just buy some time)
    rescue StandardError => e
    end
  end

  class SkalpAppObserver < Sketchup::AppObserver
    def onQuit
      Skalp.stop_skalp(true)
    end

    def onNewModel(model)
      return if model.get_attribute("Skalp", "CreateSection") == false

      Skalp.skalp_paint = PaintBucket.new
      return if Skalp.block_observers
      return unless model.valid?

      Skalp.model_collection << model unless Skalp.model_collection.include?(model)
      UI.start_timer(0.01, false) { Skalp.activate_model(model) } if Skalp.status == 1
    rescue StandardError => e
      Skalp.errors(e)
    end

    def expectsStartupModelNotifications
      true
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onOpenModel(model)
      return if model.get_attribute("Skalp", "CreateSection") == false

      Skalp.skalp_paint = PaintBucket.new
      return if Skalp.block_observers
      return unless model && model.valid?

      Skalp.model_collection << model unless Skalp.model_collection.include?(model)
      UI.start_timer(0.01, false) { Skalp.activate_model(model) } if Skalp.status == 1
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onActivateModel(model)
      return if model.get_attribute("Skalp", "CreateSection") == false

      Skalp.skalp_paint = PaintBucket.new
      return if Skalp.block_observers
      return unless model.valid?
      return unless model

      Skalp.change_active_model(model) if Skalp.status == 1 && Skalp.model_collection.include?(model)
    end
  end

  class SkalpSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(selection)
      return if Skalp.status == 0
      return unless Skalp.models[selection.model].observer_active

      data = {
        action: :changed_selection,
        selection: selection
      }
      Skalp.models[selection.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onSelectionCleared(selection)
      return if Skalp.status == 0
      return unless Skalp.models[selection.model].observer_active

      data = {
        action: :cleared_selection,
        selection: selection
      }
      Skalp.models[selection.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpLayersObserver < Sketchup::LayersObserver
    def onLayerAdded(layers, layer)
      return unless layer.valid?
      return if Skalp.status == 0
      return unless Skalp.models[layers.model].observer_active

      data = {
        action: :add_layer,
        layers: layers,
        layer: layer
      }
      Skalp.models[layers.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onCurrentLayerChanged(layers, layer)
      return unless layer && layer.valid?
      return if Skalp.status == 0
      return unless Skalp.models[layers.model].observer_active

      data = {
        action: :current_layer_changed,
        layers: layers,
        layer: layer
      }
      Skalp.models[layers.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end

    def onLayerRemoved(layers, layer)
      # return unless layer.valid?
      return if Skalp.status == 0
      return unless Skalp.models[layers.model].observer_active

      data = {
        action: :removed_layer,
        layers: layers,
        layer: layer
      }
      Skalp.models[layers.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpLayerObserver < Sketchup::EntityObserver
    def onChangeEntity(layer)
      return unless layer.valid?
      return if Skalp.status == 0
      return unless Skalp.models[layer.model]
      return unless Skalp.models[layer.model].observer_active

      # Skalp.p("layer observer #{layer}")
      data = {
        action: :changed_layer,
        layer: ""
      }
      Skalp.models[layer.model].controlCenter.add_to_queue(data)
    rescue StandardError => e
      Skalp.errors(e)
    end
  end

  class SkalpMaterialsObserver < Sketchup::MaterialsObserver
    def onMaterialChange(materials, material)
      return unless material.valid?
      return unless Skalp.models[materials.model].observer_active
      return unless Skalp.models[materials.model].material_observer_active

      Skalp.check_SU_material_library(material) if material.get_attribute("Skalp", "ID")
    end
  end
end
