# frozen_string_literal: true

if ENV.delete('COVERAGE')
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    command_name 'leopard'
    add_filter '/test/'
    add_group('Missing') { |src| src.covered_percent < 100 }
    add_group('Covered') { |src| src.covered_percent == 100 }
  end
end

require 'minitest/autorun'
require_relative '../lib/leopard'

# Suppress tests when running tests
require 'semantic_logger'
SemanticLogger.default_level = :fatal
