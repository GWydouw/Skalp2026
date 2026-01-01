# Script to inspect API methods
model = Sketchup.active_model
if model
  puts ">>> INSPECTING API <<<"

  # Check Style methods
  if model.styles.size > 0
    style = model.styles.first
    puts "Style Class: #{style.class}"
    puts "Style Methods (grep save): #{style.methods.grep(/save/)}"
    puts "Style Methods (grep write): #{style.methods.grep(/write/)}"
  end

  # Check Page methods
  if model.pages.size > 0
    page = model.pages.first
    puts "Page Class: #{page.class}"
    puts "Page Methods (grep style): #{page.methods.grep(/style/)}"
    puts "Page Methods (grep set): #{page.methods.grep(/set/)}"
    puts "Page Methods (grep update): #{page.methods.grep(/update/)}"
  end
  puts ">>> END INSPECTION <<<"
end
