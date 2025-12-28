# frozen_string_literal: true

module Skalp
  # Represents the rearview state for a single page or model.
  # Encapsulates all rearview-related data that was previously scattered
  # across multiple hashes (@uptodate, @calculated, @rear_lines_result, @rear_view_definitions).
  class RearViewState
    attr_accessor :page, :definition, :polylines, :sectionplane_id, :loaded_at

    # @param page [Sketchup::Page, Sketchup::Model] The page or model this state belongs to
    def initialize(page)
      @page = page
      @definition = nil      # ComponentDefinition containing the rearview geometry
      @polylines = nil       # PolyLines data (calculated lines)
      @sectionplane_id = nil # SectionplaneID when lines were calculated
      @loaded_at = nil       # Time when state was last updated
    end

    # Check if the current sectionplane matches what was calculated.
    # Returns true if:
    # - No calculation has been done yet (@sectionplane_id is nil)
    # - Current sectionplane ID is empty/nil
    # - Current sectionplane ID matches the calculated one
    #
    # @return [Boolean] true if rearview lines are up to date
    def uptodate?
      return true unless @sectionplane_id

      current_id = current_sectionplane_id
      return true if current_id.nil? || current_id.empty?

      @sectionplane_id == current_id
    end

    # Check if this state has any data loaded.
    #
    # @return [Boolean] true if definition or polylines are present
    def loaded?
      !@definition.nil? || !@polylines.nil?
    end

    # Check if the definition is valid and has entities.
    #
    # @return [Boolean] true if definition exists, is valid, and has entities
    def valid_definition?
      @definition && @definition.valid? && @definition.entities.size > 0
    end

    # Load existing state from a sectiongroup.
    # Looks for rearview component in the sectiongroup and loads its data.
    #
    # @param sectiongroup [Sketchup::Group] The sectiongroup containing rearview component
    # @return [Boolean] true if state was loaded successfully
    def load_from_sectiongroup(sectiongroup)
      page_name = @page.is_a?(Sketchup::Page) ? @page.name : "Model"

      return false unless sectiongroup && sectiongroup.respond_to?(:entities) && sectiongroup.entities

      # Find rearview component instance
      rear_view_instance = find_rearview_instance(sectiongroup)
      return false unless rear_view_instance

      @definition = rear_view_instance.definition

      # Load sectionplane ID for uptodate check
      @sectionplane_id = get_stored_sectionplane_id

      # Load polylines from definition attribute if available
      load_polylines_from_definition

      @loaded_at = Time.now

      if defined?(DEBUG) && DEBUG
        puts "[RearViewState] Loaded for #{page_name}:"
        puts "  definition: #{@definition&.name}"
        puts "  sectionplane_id: #{@sectionplane_id}"
        puts "  polylines_loaded: #{@polylines ? 'yes' : 'no'}"
      end

      true
    end

    # Update state after calculation.
    #
    # @param definition [Sketchup::ComponentDefinition] The rearview component definition
    # @param polylines [Hash] The calculated polylines by layer
    # @param sectionplane_id [String] The current sectionplane ID
    def update(definition:, polylines:, sectionplane_id:)
      @definition = definition
      @polylines = polylines
      @sectionplane_id = sectionplane_id
      @loaded_at = Time.now
    end

    # Update only the sectionplane_id (for uptodate sync without recalculation).
    #
    # @param sectionplane_id [String] The sectionplane ID to sync
    def sync_sectionplane_id(sectionplane_id)
      @sectionplane_id = sectionplane_id
    end

    # Clear all state for this page.
    def clear
      @definition = nil
      @polylines = nil
      @sectionplane_id = nil
      @loaded_at = nil
    end

    # Create a copy of this state for another page (used for model sync).
    #
    # @return [RearViewState] A copy of this state
    def dup_for(other_page)
      copy = RearViewState.new(other_page)
      copy.definition = @definition
      copy.polylines = @polylines
      copy.sectionplane_id = @sectionplane_id
      # Don't copy loaded_at to force refresh logic if needed, or keep it?
      # Keeping it for now.
      copy
    end

    def inspect
      "#<#{self.class}:#{object_id} @page=#{@page.is_a?(Sketchup::Page) ? @page.name : 'Model'}>"
    end

    private

    # Get the current sectionplane ID for this page.
    #
    # @return [String, nil] The current sectionplane ID
    def current_sectionplane_id
      model = Skalp.active_model
      return nil unless model

      if @page.is_a?(Sketchup::Page)
        id = model.get_memory_attribute(@page, "Skalp", "sectionplaneID")
        id ||= @page.get_attribute("Skalp", "sectionplaneID")
        id
      else
        id = model.get_memory_attribute(@page, "Skalp", "active_sectionplane_ID")
        id ||= @skp_model.get_attribute("Skalp", "active_sectionplane_ID")
        id
      end
    end

    # Get the stored sectionplane ID (for loading).
    #
    # @return [String, nil] The stored sectionplane ID
    def get_stored_sectionplane_id
      current_sectionplane_id
    end

    # Find the rearview component instance in a sectiongroup.
    #
    # @param sectiongroup [Sketchup::Group] The sectiongroup to search
    # @return [Sketchup::ComponentInstance, nil] The rearview instance or nil
    def find_rearview_instance(sectiongroup)
      sectiongroup.entities.grep(Sketchup::ComponentInstance).find do |instance|
        rearview_component?(instance)
      end
    end

    # Check if a component instance is a rearview component.
    # Uses multiple identification methods for backward compatibility.
    #
    # @param instance [Sketchup::ComponentInstance] The instance to check
    # @return [Boolean] true if this is a rearview component
    def rearview_component?(instance)
      # Primary: Skalp type attribute
      return true if instance.get_attribute("Skalp", "type") == "rear_view"

      # Fallback: Instance name pattern
      return true if instance.name =~ /^Skalp - .*rear view/i

      # Fallback: Definition name pattern
      return true if instance.definition.name =~ /^Skalp - .*rear view/i
      return true if instance.definition.name =~ /^Skalp - rear view/i

      false
    end

    # Load polylines data from the definition attribute.
    def load_polylines_from_definition
      return unless @definition

      attrib_data = @definition.get_attribute("Skalp", "rear_view_lines")
      return unless attrib_data && attrib_data != ""

      begin
        # Use safe_eval to deserialize the hash of line data
        lines_data = Skalp.safe_eval(attrib_data)
        return unless lines_data.is_a?(Hash)

        @polylines = {}
        skp_model = Skalp.active_model.skpModel

        lines_data.each do |layer_name, line_data|
          next unless line_data

          polylines = PolyLines.new
          polylines.fill_from_layout(line_data)

          # Find the corresponding SketchUp layer
          su_layer = skp_model.layers[layer_name]
          @polylines[su_layer] = polylines if su_layer
        end
      rescue StandardError => e
        if defined?(DEBUG) && DEBUG
          puts "[RearViewState] Error loading polylines for #{@page.is_a?(Sketchup::Page) ? @page.name : 'Model'}: #{e.message}"
        end
        @polylines = nil
      end
    end
  end
end
