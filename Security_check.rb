module Skalp
  def self.security_check
    if Sketchup.read_default('Skalp', 'uptodate') == false
      puts 'SERVER NOK'
    else
      puts 'SERVER OK'
    end

    if check_mac
      puts 'MAC(check) OK'
    else
      puts 'MAC(check) NOK'
    end

    if ready
      puts 'MAC(ready) OK'
    else
      puts 'MAC(ready) NOK'
    end

    if Sketchup.read_default('Skalp', 'id') == id
      puts 'ID OK'
    else
      puts 'ID NOK'
    end

    if guid == Sketchup.read_default('Skalp', 'guid')
      puts 'GUID OK'
    else
      puts 'GUID NOK'
    end

    return true
  rescue
    return false
  end
end