module Skalp
  class Layer
    attr_reader :skalpID, :observer, :skpLayer

    def initialize(skpLayer, model)
      @model = model
      @skpModel = @model.skpModel
      @skpLayer = skpLayer

      @skalpID = Skalp.get_ID(@skpLayer)
      add_observer
    end

    def to_s
      "Skalp #{Skalp.translate('layer')}: #{@skpLayer}, #{@skpLayer.name} <#{@skalpID}>"
    end

    def update_id
      @skalpID = Skalp.get_ID(@skpLayer)
    end

    def delete
      remove_observer
      delete_skpLayer
      @model.remove_layer(self)
    end

    def add_observer
      @observer = SkalpLayerObserver.new
      @skpLayer.add_observer(@observer) if @skpLayer.valid?
    end

    def remove_observer
      return unless @skpLayer
      @skpLayer.remove_observer(@observer) if @skpLayer.valid?
    end

    def delete_skpLayer
      return unless @skpLayer.valid?

      observer_status = @observer_active
      @observer_active = false

      ents = @skpModel.entities
      defs = @skpModel.definitions
      layers = @skpModel.layers


      ents.grep(Sketchup::Group) { |e| e if e.layer == @skpLayer }.each { |e| e.locked = false if e }
      layers.remove(@skpLayer, true) rescue RuntimeError

      @observer_active = observer_status
    end
  end
end
