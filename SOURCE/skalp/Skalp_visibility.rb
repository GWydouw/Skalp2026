module Skalp
  class Visibility
    attr_reader :hidden_entities, :layers

    def initialize
      @skpModel = Skalp.active_model.skpModel
      @hidden_entities = []
      @layers = []
    end

    def update(skpPage=nil)
      @hidden_entities = []
      @layers = []
      skpPage ? update_visibility(skpPage) : update_live
    end

    # def visible_in_scene?(layer, scene)
    #   scene.layers.include?(layer) == hidden_by_default?(layer)
    # end
    #
    # def hidden_by_default?(layer)
    #   layer.page_behavior & LAYER_HIDDEN_BY_DEFAULT == LAYER_HIDDEN_BY_DEFAULT
    # end

    def update_visibility(skpPage)
      if skpPage
        get_hidden_layers(skpPage)
      else
        update_live_layers
      end
      if skpPage.use_hidden_objects?
        @hidden_entities = skpPage.hidden_entities
        @hidden_entities += find_hidden(false)
      else
        update_live_entities
      end
    end

    def get_hidden_layers(skpPage)
      @layers = skpPage.layers
      @folders = []
      skpPage.layer_folders.each do |folder|
        @folders << folder unless @folders.include?(folder)
        get_folders(folder)
      end

      @folders.each do |folder|
        folder.layers.each do |layer|
          @layers << layer unless @layers.include?(layer)
        end
      end
    end

    def get_folders(folder)
      folder.each_folder do |f|
        @folders << f unless @folders.include?(f)
        get_folders(f)
      end
    end

    def include_layer?(layer)
      return false if layer.deleted?
      @layers.select! { |l| l if l.valid? }
      @layers.include?(layer)
    end

    def include_hidden_entity?(entity)
      return false if entity.deleted?
      @hidden_entities.select! { |e| e if e.valid? }
      @hidden_entities.include?(entity)
    end

    def update_live
      update_live_layers
      update_live_entities
    end

    def update_live_layers
      layers = @skpModel.layers
      return unless layers
      for layer in layers
        @layers << layer unless layer_visible?(layer)
      end
    end

    def layer_visible?(layer)
      if layer.visible?
        return folder_visible?(layer)
      else
        return false
      end
    end

    def folder_visible?(child)
      folder = child.folder
      if folder
        if folder.visible?
          return folder_visible?(folder)
        else
          return false
        end
      else
        return true
      end
    end

    def update_live_entities
      @hidden_entities = find_hidden(true)
    end

    def find_hidden(model = true)
      hidden = []
      return hidden unless (@skpModel && @skpModel.definitions)

      @skpModel.definitions.each do |definition|
        next if definition.class != Sketchup::ComponentDefinition
        definition.instances.each do |i|
          model ? (hidden << i if i.hidden?) : (hidden << i if i.hidden? && i.parent.class != Sketchup::Model)
        end
      end
      hidden
    end

    def check_visibility(entity)
      return false if @hidden_entities.include?(entity)
      return false if @layers.include?(entity.layer)
      return true
    end
  end
end
