# frozen_string_literal: true

unless defined?(SketchupExtension)
  class SketchupExtension
    attr_accessor :version, :description, :copyright, :creator

    def initialize(name, path)
      @name = name
      @path = path
    end
  end
end
