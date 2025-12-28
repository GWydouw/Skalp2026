
  def ccA(skpLayer)
    layer =  @model.layers[skpLayer]
    if layer
      @model.remove_layer(layer)
      layer.remove_observer
    end
  end
