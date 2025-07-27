# frozen_string_literal: true

require 'rake'
require 'minitest/test_task'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

Minitest::TestTask.create(:test) do |task|
  task.libs << 'lib'
  task.libs << 'test'
  task.test_globs = ['test/*/**/*.rb']
  task.warning = true
end

task default: %i[rubocop test]
