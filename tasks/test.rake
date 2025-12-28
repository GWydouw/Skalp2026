# frozen_string_literal: true

# Testing and verification tasks

require "rake/testtask"

desc "Run headless unit tests (Minitest)"
Rake::TestTask.new(:test) do |t|
  t.libs << "tests"; t.libs << "tests/unit"
  t.pattern = "tests/unit/**/test_*.rb"
  t.verbose = true
end

namespace :test do
  VERIFICATION_FILE = ".test_verification"
  SHA_INJECTION_FILE = "tests/.current_git_sha"

  desc "Inject Current git SHA for TestUp (Private)"
  task :inject_sha do
    sha = `git rev-parse HEAD`.strip
    File.write(SHA_INJECTION_FILE, sha)
    # Also invalidate old verification on dev start
    File.delete(VERIFICATION_FILE) if File.exist?(VERIFICATION_FILE)
  end

  desc "Cleanup Injected SHA (Private)"
  task :cleanup_sha do
    File.delete(SHA_INJECTION_FILE) if File.exist?(SHA_INJECTION_FILE)
  end

  desc "[DEPRECATED] Mark Integration Tests as Passed (Manual)"
  task :mark_integration_passed_manual do
    puts "⚠️  DEPRECATION WARNING: Please use the 'Verification' test case inside TestUp instead."
    commit = `git rev-parse HEAD`.strip
    timestamp = Time.now.to_s
    File.write(VERIFICATION_FILE, "#{commit}|#{timestamp}")
    puts "✅ Integration Tests MARKED AS PASSED (Manually) for: #{commit[0..7]}"
  end

  task :verify_publish_status do
    current_commit = `git rev-parse HEAD`.strip

    passed = false
    if File.exist?(VERIFICATION_FILE)
      content = File.read(VERIFICATION_FILE).strip
      verified_commit, timestamp = content.split("|")
      if verified_commit == current_commit
        puts "✅ Verified Integration Tests passed at #{timestamp}"
        passed = true
      else
        puts "⚠️  Verification outdated! (Verified: #{verified_commit[0..7]}, Current: #{current_commit[0..7]})"
      end
    else
      puts "⚠️  No integration test verification found."
    end

    unless passed
      puts "⚠️  WARNING: You are publishing without verified Integration Tests (TestUp2)."
      print "   Continue anyway? [y/N] "
      input = $stdin.gets.strip.downcase
      abort "❌ Publish aborted." unless input == "y"
    end
  end

  task :offer_invalidation do
    if File.exist?(VERIFICATION_FILE)
      puts "\n❓ Do you want to invalidate the current test verification? (Good hygiene for next dev cycle)"
      print "   Invalidate? [y/N] "
      input = $stdin.gets.strip.downcase
      if input == "y"
        File.delete(VERIFICATION_FILE)
        puts "🗑️  Verification file deleted."
      end
    end
  end

  desc "Run meta-tests (build integrity, tooling verification)"
  task :meta do
    puts "🔧 Running Meta-Tests..."

    # 1. IntegrityCheck unit tests
    puts "\n[1/2] IntegrityCheck Tests..."
    sh "ruby tests/meta/test_build_integrity.rb"

    # 2. Full build pipeline verification
    puts "\n[2/2] Build Pipeline Verification..."
    sh "ruby tools/verify_build.rb"

    puts "\n✅ All meta-tests passed!"
  end

  desc "Run all tests (unit + meta)"
  task all: %i[test meta] do
    puts "\n🎉 All test suites passed!"
  end
end

namespace :log do
  desc "Clear UI Debug Log"
  task :clear do
    log_path = File.join(Config::PROJECT_ROOT, "test_logs", "ui_debug.log")
    if File.exist?(log_path)
      File.write(log_path, "")
      puts "🧹 Cleared ui_debug.log"
    end
  end
end
