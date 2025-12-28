def ccA(*args)
  t = rand(10)
  timer_started = false
  UI.stop_timer(@no_license) if @no_license != nil
  @no_license = UI.start_timer(t, false) {
    unless timer_started
      timer_started = true
      UI.messagebox('NO VALID SKALP LICENSE FOUND,
  please contact us at support@skalp4sketchup.com')
    end
  }

  #self.instance_eval {undef :ccA}
end


