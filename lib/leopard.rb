# frozen_string_literal: true

require 'dry/configurable'
require 'pathname'
require 'semantic_logger'
SemanticLogger.add_appender(io: $stdout, formatter: :color)

class Pathname
  def /(other)
    join other.to_s
  end
end

module Rubyists
  module Leopard
  end
end

require_relative 'leopard/settings'
require_relative 'leopard/version'
require_relative 'leopard/errors'
