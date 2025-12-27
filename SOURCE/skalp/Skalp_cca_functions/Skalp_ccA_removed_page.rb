def ccA(page_deleted)
  id = @model.skalp_pages_LUT[page_deleted]
  return unless id

  if @model.pages && @model.pages[page_deleted]
    @undo_action[:page_changed]={
        :name => @model.pages[page_deleted].name,
        :action => :deleted,
        :id => id
    }
  end

  @model.pages.delete(page_deleted) if @model.pages
  @model.skalp_pages_LUT.delete(page_deleted)
  layer = @model.layer_by_id(id)

  if layer && layer.skpLayer.valid?
    @model.start(Skalp.translate('Skalp - delete Skalp scene layer'))
    layer.delete
    @model.commit
  end

end
