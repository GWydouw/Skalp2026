# frozen_string_literal: true

module Skalp
  # Central manager for rearview states across all pages.
  # Replaces the scattered state management in Hiddenlines with a unified approach.
  class RearViewManager
    REARVIEW_TYPE_ATTRIBUTE = "rear_view"

    attr_reader :states

    # @param hiddenlines [Skalp::Hiddenlines] Reference to hiddenlines for model access
    def initialize(hiddenlines)
      @hiddenlines = hiddenlines
      @model = hiddenlines.model
      @skp_model = @model.skpModel
      @states = {} # page => RearViewState
    end

    def inspect
      "#<#{self.class}:#{object_id} @model=#{@model}>"
    end

    # Get state for a page (lazy initialization).
    # Creates a new RearViewState if one doesn't exist.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @return [RearViewState] The state for this page
    def [](page)
      @states[page] ||= RearViewState.new(page)
    end

    # Set state for a page directly.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @param state [RearViewState] The state to set
    def []=(page, state)
      @states[page] = state
    end

    # Check if a page has any rearview state.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @return [Boolean] true if state exists for this page
    def has_state?(page)
      @states.key?(page)
    end

    # Load all existing rearview definitions from the model.
    # Called during model initialization.
    def load_all
      # Load for all pages
      @skp_model.pages.each { |page| load_for_page(page) }

      # Load for model-level
      load_for_page(@skp_model)

      return unless defined?(DEBUG) && DEBUG

      puts "[RearViewManager] Loaded #{@states.count} rearview states"
      @states.each do |page, state|
        page_name = page.is_a?(Sketchup::Page) ? page.name : "Model"
        puts "  #{page_name}: loaded=#{state.loaded?}, uptodate=#{state.uptodate?}"
      end
    end

    # Check if a page's rearview lines are up to date.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @return [Boolean] true if rearview lines are up to date
    def uptodate?(page)
      return true unless has_state?(page)

      self[page].uptodate?
    end

    # Get the definition for a page.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @return [Sketchup::ComponentDefinition, nil] The rearview definition
    def definition(page)
      return nil unless has_state?(page)

      self[page].definition
    end

    # Get the polylines for a page.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @return [Hash, nil] The polylines by layer
    def polylines(page)
      return nil unless has_state?(page)

      self[page].polylines
    end

    # Update state after calculation.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @param definition [Sketchup::ComponentDefinition] The rearview component definition
    # @param polylines [Hash] The calculated polylines by layer
    # @param sectionplane_id [String] The current sectionplane ID
    def update(page, definition:, polylines:, sectionplane_id:)
      self[page].update(
        definition: definition,
        polylines: polylines,
        sectionplane_id: sectionplane_id
      )
    end

    # Sync sectionplane_id for a page (without full recalculation).
    # Used to update uptodate status after calculation on related page.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    # @param sectionplane_id [String] The sectionplane ID to sync
    def sync_sectionplane_id(page, sectionplane_id)
      self[page].sync_sectionplane_id(sectionplane_id)
    end

    # Sync the selected page's state to the model.
    # Called when switching pages to keep model state in sync.
    #
    # @param selected_page [Sketchup::Page] The currently selected page
    def sync_to_model(selected_page)
      return unless selected_page
      return unless has_state?(selected_page)

      # Copy state from selected page to model
      @states[@skp_model] = @states[selected_page].dup_for(@skp_model)
    end

    # Remove state for a page when sectionplane changes.
    #
    # @param sectionplane_id [String] The changed sectionplane ID
    def clear_for_sectionplane(sectionplane_id)
      @states.delete_if { |_page, state| state.sectionplane_id == sectionplane_id }
    end

    # Clear state for a specific page.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    def clear(page)
      return unless has_state?(page)

      self[page].clear
    end

    # Remove invalid pages from states (cleanup).
    def remove_invalid_pages
      @states.delete_if do |page, _state|
        invalid = page.is_a?(Sketchup::Page) && !page.valid?
        puts "[RearViewManager] Removing invalid page state" if invalid && defined?(DEBUG) && DEBUG
        invalid
      end
    end

    # Backward compatibility: return hash-like accessor for @uptodate
    # Returns a hash where values are sectionplane_ids
    def uptodate_hash
      result = {}
      @states.each do |page, state|
        result[page] = state.sectionplane_id if state.sectionplane_id
      end
      result
    end

    # Backward compatibility: return hash-like accessor for @calculated
    # Currently same as uptodate_hash since they were always the same
    def calculated_hash
      uptodate_hash
    end

    # Backward compatibility: return hash-like accessor for @rear_view_definitions
    def definitions_hash
      result = {}
      @states.each do |page, state|
        result[page] = state.definition if state.definition
      end
      result
    end

    # Backward compatibility: return hash-like accessor for @rear_lines_result
    def polylines_hash
      result = {}
      @states.each do |page, state|
        result[page] = state.polylines if state.polylines
      end
      result
    end

    private

    # Load rearview state for a specific page.
    #
    # @param page [Sketchup::Page, Sketchup::Model] The page or model
    def load_for_page(page)
      state = self[page]

      # Get sectiongroup internally using send to access the method
      sectiongroup = @hiddenlines.send(:get_sectiongroup, page)
      return unless sectiongroup

      state.load_from_sectiongroup(sectiongroup)
    end
  end
end
