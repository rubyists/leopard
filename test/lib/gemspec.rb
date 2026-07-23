# frozen_string_literal: true

require 'helper'

describe 'leopard gemspec' do
  let(:specification) { Gem::Specification.load((Rubyists::Leopard.root / 'leopard.gemspec').to_s) }
  let(:semantic_logger_requirement) do
    specification.runtime_dependencies.find { |dependency| dependency.name == 'semantic_logger' }.requirement
  end

  it 'supports semantic_logger 4.x and newer' do
    refute semantic_logger_requirement.satisfied_by?(Gem::Version.new('3.9.9'))
    assert semantic_logger_requirement.satisfied_by?(Gem::Version.new('4.0.0'))
    assert semantic_logger_requirement.satisfied_by?(Gem::Version.new('5.0.0'))
    assert semantic_logger_requirement.satisfied_by?(Gem::Version.new('6.0.0'))
  end
end
