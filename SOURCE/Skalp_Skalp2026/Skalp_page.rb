module Skalp
  class Page
    attr_accessor :sectionplane, :name
    attr_reader :skpPage, :skalpID, :model

    def initialize(object, new = false, fix_existing_page = false)
      return unless Skalp.active_model
      @model = Skalp.active_model
      @skpModel = @model.skpModel
      #read_attributes
      case object
        when Sketchup::Page
          return unless object.valid?

          object.use_section_planes = true
          object.use_style = true
          object.use_hidden = true
          object.use_hidden_layers = true
          object.use_camera = true

          mask = 0
          mask = mask + 1 unless object.camera  #Camera location
          mask = mask + 2 unless object.style  # Drawing style
          mask = mask + 16  unless object.hidden_entities      #Hidden Geometry
          mask = mask + 32 unless object.layers    #Visible Layers

          object.update(mask) if mask > 0

          @skpPage = object
          if new && @model.active_sectionplane
            @sectionplane = @model.active_sectionplane

            Skalp.set_ID(@skpPage)

            unless @model.get_memory_attribute(@skpPage, 'Skalp', 'sectionplaneID')
              @model.set_memory_attribute(@skpPage, 'Skalp', 'sectionplaneID', @sectionplane.skalpID) if @sectionplane.skalpID
              @skpPage.name = generate_name unless fix_existing_page
            end

            Skalp.dialog.settings_to_page(object) if @model.save_settings
          else
            # SU 2026: Use dynamic helper that favors native scene state
            @sectionplane = @model.active_sectionplane_for_page(@skpPage)
          end
        when SectionPlane
          @sectionplane = object
          make_skpPage
          if new
            @model.set_memory_attribute(@skpPage, 'Skalp', 'sectionplaneID', @sectionplane.skalpID)
            Skalp.set_ID(@skpPage)
            if @model.save_settings
              Skalp.dialog.settings_to_page(Sketchup.active_model.pages.selected_page)
              Skalp.dialog.save_settings_checkbox_on
            end
          end

          @model.pages[@skpPage] = self
      end
      return unless @sectionplane
      @sectionplane.add_page(self)
      @skpPage.description = generate_description
      @model.skalp_pages_LUT[@skpPage] = @model.get_memory_attribute(@skpPage, 'Skalp', 'ID')
      @skalpID = Skalp.get_ID(@skpPage)

    rescue => e
      Skalp.errors(e)
    end

    def to_s
      "Skalp page: #{@skpPage}, #{@skpPage.name} <#{@skalpID}>"
    end

    def make_skpPage
      observer_status = @model.observer_active
      @model.observer_active = false

      @name = generate_name
      @skpPage = @model.skpModel.pages.add(@name)

      @skpPage.use_section_planes = true
      @skpPage.use_style = true
      @skpPage.use_hidden = true
      @skpPage.use_hidden_layers = true
      @skpPage.use_camera = true

    rescue => e
      Skalp.errors(e)

    ensure
      @model.observer_active = observer_status
    end

    def delete
      return unless @skpPage.valid?
      @skpPage.delete_attribute('Skalp') if @skpPage.get_attribute('Skalp', 'ID')
      @model.clear_memory_attributes(@skpPage)
    end

    def page_layer
      @model.layer_by_id(@skalpID)
    end

    def generate_description
      return "#{@sectionplane.sectionplane_name} (#{@representation_value})"
    rescue => e
      Skalp.errors(e)
      #TODO controleer en ruim eventueel skalp page op
    end

    def generate_name
      count = 0
      name = @sectionplane.sectionplane_name
      return '' unless (name && @skpModel && @skpModel.pages)
      while @skpModel.pages[name]
        count += 1
        name = @sectionplane.sectionplane_name + ' ' + count.to_s
      end
      name
    rescue => e
      Skalp.errors(e)
      #TODO controleer en ruim eventueel skalp page op
    end
  end
end
