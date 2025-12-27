# frozen_string_literal: true

# Release and publish tasks

desc "Release Cycle (Bump -> Build -> Verify -> Tag)"
task :release, [:version] do |_t, args|
  bump_arg = args[:version]
  abort("Usage: rake release[major|minor|patch|X.Y.Z]") unless bump_arg

  puts "🚢 Starting Release Process..."

  # 1. Calculate Target Version
  target_version = `ruby tools/bump_version.rb next #{bump_arg}`.strip
  abort("❌ Error calculating version from '#{bump_arg}'") unless target_version.match?(/^\d+\.\d+\.\d+$/)

  puts ">> Target Version: v#{target_version}"

  # 2. Safety Check: Run Tests & Lint
  puts "🧪 Running Test Suite..."
  Rake::Task["test"].invoke
  puts "✅ Tests passed."

  puts "🎨 Running Lint Checks..."
  Rake::Task["lint"].invoke
  puts "✅ Linting passed."

  # 3. Generate Release Notes
  puts "📝 Generating Release Notes..."
  sh "ruby tools/gen_release_notes.rb #{target_version}"
  puts "✅ Release Notes updated."

  # 4. Apply Bump (Git Commit & Tag)
  sh "ruby tools/bump_version.rb apply #{target_version}"

  # 5. Build Release Artifact
  Rake::Task["build:release"].invoke

  # 6. Docs
  Rake::Task["docs"].invoke

  # 7. Verify
  sh "./tools/verify_build.rb"

  puts "🎉 Release v#{target_version} Ready!"
  puts "👉 Run 'rake publish' to push to GitHub and trigger the build workflow."
end

# Zsh-safe aliases
namespace :release do
  desc "Release Patch (X.Y.Z+1)"
  task :patch do
    Rake::Task["release"].invoke("patch")
  end

  desc "Release Minor (X.Y+1.0)"
  task :minor do
    Rake::Task["release"].invoke("minor")
  end

  desc "Release Major (X+1.0.0)"
  task :major do
    Rake::Task["release"].invoke("major")
  end
end

desc "Publish to GitHub (Push commits & tags)"
task publish: ["test:verify_publish_status"] do
  puts "🚀 Publishing to GitHub..."

  # 1. Check Branch
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  unless branch == "main"
    puts "⚠️  You are on branch '#{branch}'. Usually releases are published from 'main'."
    print "   Continue anyway? [y/N] "
    input = $stdin.gets.strip.downcase
    abort "❌ Publish aborted." unless input == "y"
  end

  # 2. Push Commits
  puts "⬆️  Pushing commits..."
  sh "git push origin #{branch}"

  # 3. Push Tags
  puts "🏷️  Pushing tags..."
  sh "git push origin --tags"

  puts "✅ Published! GitHub Actions should now be building your release."

  Rake::Task["test:offer_invalidation"].invoke
end
