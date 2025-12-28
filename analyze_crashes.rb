# analyze_crashes.rb

# Configuration
SQL_FILE = "/Users/guywydouw/Dropbox/Guy/SourceTree_repo/Skalp 2026/skalp_2025-12-28.sql"
START_DATE = "2022-01-01"

require "date"
require "json"

puts "Analyzing crashes since #{START_DATE}..."

stats = {
  total_processed: 0,
  relevant_crashes: 0,
  by_error: Hash.new(0),
  by_version: Hash.new(0),
  by_su_version: Hash.new(0),
  details: {}
}

def parse_line(line)
  return nil unless line.strip.start_with?("(")

  content = line.strip.sub(/^\(/, "").sub(/\)[,;]?$/, "")

  values = []
  current_value = ""
  in_quote = false
  escape = false

  content.each_char do |char|
    if escape
      current_value << char
      escape = false
    elsif char == "\\"
      current_value << char
      escape = true
    elsif char == "'"
      in_quote = !in_quote
      current_value << char
    elsif char == "," && !in_quote
      values << current_value.strip
      current_value = ""
    else
      current_value << char
    end
  end
  values << current_value.strip

  values.map! { |v| v.start_with?("'") && v.end_with?("'") ? v[1..-2] : v }

  {
    id: values[0],
    guid: values[1],
    os: values[2],
    error_class: values[3],
    backtrace: values[4],
    message: values[5],
    version: values[6],
    su_version: values[7],
    commit: values[11],
    created_on: values[12]
  }
end

File.foreach(SQL_FILE) do |line|
  stats[:total_processed] += 1

  puts "Processed #{stats[:total_processed]} lines..." if stats[:total_processed] % 100_000 == 0

  # Optimization: Quick pre-check for year
  next unless line.include?("'2022-") || line.include?("'2023-") || line.include?("'2024-") || line.include?("'2025-")

  next unless line.strip.start_with?("(")

  begin
    data = parse_line(line)
    next unless data
    next unless data[:created_on]

    if data[:created_on] >= START_DATE
      stats[:relevant_crashes] += 1

      msg = data[:message].to_s.slice(0, 200)

      bt_signature = "No Backtrace"
      if data[:backtrace]
        # Try to extract the first file:line references
        # Simple regex for .rb:123
        bt_signature = if match = data[:backtrace].match(%r{([a-zA-Z0-9_\-/]+\.rb:\d+)})
                         match[1]
                       else
                         data[:backtrace].slice(0, 50)
                       end
      end

      group_key = "#{data[:error_class]}: #{msg} @ #{bt_signature}"

      stats[:by_error][group_key] += 1
      stats[:by_version][data[:version]] += 1
      stats[:by_su_version][data[:su_version]] += 1

      stats[:details][group_key] = data unless stats[:details].has_key?(group_key)
    end
  rescue StandardError => e
    # ignore
  end
end

puts "\n=== ANALYSIS REPORT ==="
puts "Total Lines Processed: #{stats[:total_processed]}"
puts "Relevant Crashes (>= #{START_DATE}): #{stats[:relevant_crashes]}"

puts "\n--- TOP 20 CRASHES ---"
sorted_errors = stats[:by_error].sort_by { |k, v| -v }.first(20)

sorted_errors.each_with_index do |(key, count), index|
  puts "\n#{index + 1}. COUNT: #{count}"
  puts "   ERROR: #{key}"
  sample = stats[:details][key]
  puts "   LATEST SAMPLE: #{sample[:created_on]} (v#{sample[:version]} on SU#{sample[:su_version]})"
end

puts "\n--- SKALP VERSIONS ---"
stats[:by_version].sort_by { |k, v| -v }.each do |k, v|
  puts "#{k}: #{v}"
end

puts "\n--- SKETCHUP VERSIONS ---"
stats[:by_su_version].sort_by { |k, v| -v }.each do |k, v|
  puts "#{k}: #{v}"
end
