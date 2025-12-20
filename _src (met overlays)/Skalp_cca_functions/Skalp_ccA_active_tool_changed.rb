
  def ccA(tool_id)
    return if view_operation?(tool_id)

    @tool_finished = false if tool_id == 21048 || tool_id == 21041
    @tool_finished = true   if tool_id != 21048 && tool_id != 21041
    @tool_changed = true if tool_id != @last_used_tool
    @last_used_tool = tool_id
    #self.instance_eval {undef :ccA}
  end

  def view_operation?(tool_id)
    if tool_id == 10508 || tool_id == 10509 || tool_id == 10523 || tool_id == 10526
      return true
    else
      return false
    end
  end
