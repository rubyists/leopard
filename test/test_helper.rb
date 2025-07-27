# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

if (coverage = ENV.delete('COVERAGE'))
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    command_name coverage
    add_filter '/test/'
    add_group('Missing') { |src| src.covered_percent < 100 }
    add_group('Covered') { |src| src.covered_percent == 100 }
  end
end

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'
