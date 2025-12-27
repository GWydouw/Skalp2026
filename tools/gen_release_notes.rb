#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "date"

class ReleaseNotesGenerator
  RELEASE_NOTES_FILE = "RELEASE_NOTES.md"

  def run(new_version)
    puts "📝 Generating release notes for v#{new_version}..."

    last_tag = get_last_tag
    puts "   Last tag: #{last_tag || 'None (Initial Release)'}"

    commits = get_commits(last_tag)
    if commits.empty?
      puts "   No new commits found."
      return
    end

    categorized = categorize_commits(commits)
    notes = format_notes(new_version, categorized)

    prepend_notes(new_version, notes)
    puts "✅ Added release notes to #{RELEASE_NOTES_FILE}"
  end

  private

  def get_last_tag
    stdout, _, status = Open3.capture3("git describe --tags --abbrev=0")
    status.success? ? stdout.strip : nil
  end

  def get_commits(last_tag)
    range = last_tag ? "#{last_tag}..HEAD" : "HEAD"
    stdout, _, short_log_status = Open3.capture3("git log #{range} --pretty=format:'%s' --no-merges")

    # Fallback if range fails (e.g. detached head or first run nuances), but typically reliable
    return [] unless short_log_status.success?

    stdout.split("\n").map(&:strip).reject(&:empty?)
  end

  def categorize_commits(commits)
    categories = {
      "✨ Features" => [],
      "🐛 Bug Fixes" => [],
      "🔧 Maintenance & Chores" => [],
      "📝 Documentation" => [],
      "Other" => []
    }

    commits.each do |msg|
      case msg
      when /^feat(\(.*\))?:/
        categories["✨ Features"] << format_msg(msg)
      when /^fix(\(.*\))?:/
        categories["🐛 Bug Fixes"] << format_msg(msg)
      when /^chore(\(.*\))?:/, /^refactor(\(.*\))?:/, /^test(\(.*\))?:/, /^style(\(.*\))?:/, /^ci(\(.*\))?:/
        categories["🔧 Maintenance & Chores"] << format_msg(msg)
      when /^docs(\(.*\))?:/
        categories["📝 Documentation"] << format_msg(msg)
      else
        categories["Other"] << msg
      end
    end

    categories.reject { |_, msgs| msgs.empty? }
  end

  def format_msg(msg)
    # Remove the prefix (feat: ...) and capitalize first letter
    clean = msg.sub(/^[a-z]+(\(.*\))?:\s*/, "")
    clean = clean[0].upcase + clean[1..] if clean.length.positive?
    clean.to_s
  end

  def format_notes(version, categorized)
    date = Date.today.strftime("%Y-%m-%d")
    out = []
    out << "## [#{version}] - #{date}"
    out << ""

    categorized.each do |title, lines|
      out << "### #{title}"
      lines.each { |l| out << "- #{l}" }
      out << ""
    end

    out.join("\n")
  end

  def prepend_notes(version, new_content)
    # Read existing file
    content = File.exist?(RELEASE_NOTES_FILE) ? File.read(RELEASE_NOTES_FILE) : "# Release Notes\n\n"

    # Regex to find an existing section for this version
    # Matches "## [version]" at start of line, until the next "## [" or End of file
    # /m modifier makes (.*?) match newlines
    pattern = /^## \[#{Regexp.escape(version)}\].*?(?=^## \[|\z)/m

    if content.match?(pattern)
      puts "   ♻️  Replacing existing entries for v#{version}..."
      # Replace the found block with the new content (ensure trailing newlines for spacing)
      final_content = content.sub(pattern, "#{new_content}\n\n")
      # Clean up potential double blank lines created by replacement
      final_content = final_content.gsub(/\n{3,}/, "\n\n")
    elsif content.match(/^# Release Notes\s+/)
      # Prepend logic (insert after main header)
      header = content.match(/^# Release Notes\s+/)[0]
      rest = content.sub(/^# Release Notes\s+/, "")
      final_content = "#{header}\n#{new_content}\n\n#{rest}"
    else
      final_content = "# Release Notes\n\n#{new_content}\n\n#{content}"
    end

    File.write(RELEASE_NOTES_FILE, "#{final_content.strip}\n")
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: ruby tools/gen_release_notes.rb <new_version>"
    exit 1
  end
  ReleaseNotesGenerator.new.run(ARGV[0])
end
