# frozen_string_literal: true

# Code linting tasks

namespace :lint do
  desc "Lint Ruby code (RuboCop)"
  begin
    require "rubocop/rake_task"
    RuboCop::RakeTask.new(:ruby) do |t|
      t.options = ["--display-cop-names", "--format", "progress"]
    end
  rescue LoadError
    task :ruby do
      abort "⚠️  RuboCop not loaded. Run 'bundle install' first."
    end
  end

  desc "Lint Web code (ESLint)"
  task :web do
    puts "🎨 Linting Web..."
    run_cmd "cd \"#{Config::WEB_DIR}\" && npm run lint"
  end
end

desc "Lint all code (Ruby only for now)"
task lint: ["lint:ruby"]
