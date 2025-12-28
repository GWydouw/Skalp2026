module Skalp
  class SectionPlane

    @@num_skalp_sectionplanes = 0

    attr_reader :observer, :skpSectionPlane, :skalpID, :section, :pages, :skpModel, :normal
    attr_accessor :plane

    def initialize(skpSectionPlane, model)
      @pages = []
      @skpSectionPlane = skpSectionPlane
      @plane = @skpSectionPlane.get_plane
      @model = model
      @model.sectionplane_entityIDs << skpSectionPlane.entityID
      @skpModel = @model.skpModel
      @sectionplane_name = @skpSectionPlane.get_attribute('Skalp', 'sectionplane_name')
      @section = Skalp::Section.new(self)
      @skalpID = Skalp.get_ID(@skpSectionPlane)
      add_observer
      make_skalp_sectionplane
    end

    def activate
      @model.set_active_sectionplane(@skalpID)
      calculate_section
    end

    def add_observer
      Skalp.message1 unless Sketchup.read_default('Skalp', 'id') == Skalp.id
      @observer = SkalpEntityObserver.new
      @skpSectionPlane.add_observer(@observer)
    end

    def remove_observer
      @skpSectionPlane.remove_observer(@observer)
    end

    def sectionplane_name
      return unless @skpSectionPlane.valid?
      @skpSectionPlane.get_attribute('Skalp', 'sectionplane_name')
    end

    def add_page(page)
      @pages << page
    end

    def normal
      Geom::Vector3d.new @plane[0], @plane[1], @plane[2]
    end

    def name
      @sectionplane_name
    end

    def transformation
      global_zaxis = Geom::Vector3d.new(0, 0, 1)
      origin = Geom::Point3d.new(-@plane[0]*@plane[3], -@plane[1]*@plane[3], -@plane[2]*@plane[3])
      #z_height = origin.z
      zaxis = Geom::Vector3d.new(-@plane[0], -@plane[1], -@plane[2]) # OK! deze 3 punten mogen ook van teken veranderen, kwestie van keuze normaalvector uiteindelijke groep

      if zaxis.parallel? global_zaxis then
        if zaxis.samedirection? global_zaxis then #IDENTIEKE Z ASSEN, TEGENGESTELDE RICHTING!
          xaxis = Geom::Vector3d.new(1, 0, 0) #hint:spiegelen door x en y te wisselen of cross om te draaien.
          yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
        else #IDENTIEKE Z ASSEN, ZELFDE RICHTING!
          xaxis = Geom::Vector3d.new(1, 0, 0)
          yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
        end
      else
        xaxis = global_zaxis.cross zaxis #cross omdraaien inverteert richting resulterende vector
        yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
      end

      transformation = Geom::Transformation.axes origin, xaxis, yaxis, zaxis
      transformation.invert!
    end

    def calculate_section(force_update=true, skpPage=nil) #TODO calculate_section wordt regelmatig 2x getriggerd zonder dat dit nodig is!
      if @skpSectionPlane.valid?
        return unless Skalp.live_section_ON || skpPage
        return if Skalp.sectionplane_active == false && !skpPage
        @section.update(skpPage, force_update)
      else
        @model.delete_sectionplane(self, true)
      end
    end

    def make_skalp_sectionplane
      @@num_skalp_sectionplanes += 1
      @skalpID ? new_sectionplane = false : new_sectionplane = true
      make_id

      if new_sectionplane
        Page.new(self, true) if @model.make_scene
        activate #TODO bij nieuw bestaat er nog geen active sectionplane
        Skalp.dialog.update(1, @sectionplane_name)
      end
    end

    def make_id
      Skalp.set_ID(@skpSectionPlane)
      @skalpID = Skalp.get_ID(@skpSectionPlane)
    end

    def delete
      unlink_pages
    end

    def unlink_pages
      @pages.each do |page|
        next unless page
        page.delete if page.skpPage && page.skpPage.valid?
      end
    end

    def rename(new_name)
      #update metadata
      @skpSectionPlane.set_attribute('Skalp', 'sectionplane_name', new_name)

      rename_pages(new_name)
      Skalp.dialog.update(1)
    end

    def rename_pages(new_name)
      #rename pages
      for page in @pages
        page.skpPage.name = page.skpPage.name.sub(@sectionplane_name, new_name)
      end

      @sectionplane_name = new_name
    end
  end
end
