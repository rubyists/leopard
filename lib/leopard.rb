# frozen_string_literal: true

require 'dry/configurable'
require 'pathname'

class Pathname
  def /(other)
    join other.to_s
  end
end

module Rubyists
  module Leopard
    extend Dry::Configurable
  end
end

require_relative 'leopard/version'
require_relative 'leopard/errors'
require_relative 'leopard/settings'
