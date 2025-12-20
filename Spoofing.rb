# alias_method_chain
# Provides a way to 'sneak into and spoof'TM original Sketchup API methods :)
# http://erniemiller.org/2011/02/03/when-to-use-alias_method_chain/

module Method_spoofer
  def self.included(base)
    base.class_eval do
      alias_method :start_operation_without_method_spoofer, :start_operation
      alias_method :start_operation, :start_operation_with_method_spoofer

      alias_method :commit_operation_without_method_spoofer, :commit_operation
      alias_method :commit_operation, :commit_operation_with_method_spoofer

      alias_method :abort_operation_without_method_spoofer, :abort_operation
      alias_method :abort_operation, :abort_operation_with_method_spoofer

      alias_method :entityID_without_method_spoofer, :entityID
      alias_method :entityID, :entityID_with_method_spoofer
    end
  end

  def start_operation_with_method_spoofer(*params)
    pp "START OPERATION: #{caller_locations(1, 1)[0].label}"
    start_operation_without_method_spoofer(*params)
  end

  def commit_operation_with_method_spoofer(*params)
    pp "COMMIT OPERATION: #{caller_locations(1, 1)[0].label}"
    commit_operation_without_method_spoofer(*params)
  end

  def abort_operation_with_method_spoofer(*params)
    pp "ABORT OPERATION: #{caller_locations(1, 1)[0].label}"
    abort_operation_without_method_spoofer(*params)
  end

  def entityID_with_method_spoofer(*params)
    pp "ENTITY ID: #{caller_locations}"
    pp *params
    entityID_without_method_spoofer(*params)
  end
end

Sketchup::Model.send :include, Method_spoofer



module Method_spoofer
  def self.included(base)
    base.class_eval do
      alias_method :visible_without_method_spoofer, :visible=
      alias_method :visible=, :visible_with_method_spoofer
    end
  end

  def visible_with_method_spoofer(*params)
    if self.name == 'kasten'
      pp "visible=: #{caller_locations}"
    end
    visible_without_method_spoofer(*params)
  end
end

Sketchup::Layer.send :include, Method_spoofer



module Method_spoofer
  def self.included(base)
    base.class_eval do
      alias_method :without_method_spoofer, :onViewChanged
      alias_method :visible=, :with_method_spoofer
    end
  end

  def with_method_spoofer(*params)
    pp "onViewChanged: #{caller_locations}"
    without_method_spoofer(*params)
  end
end

Sketchup::ViewObserver.send :include, Method_spoofer






