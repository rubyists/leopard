# frozen_string_literal: true

require 'dry/configurable'

module Rubyists
  module Leopard
    extend Dry::Configurable
  end
end

require_relative 'leopard/version'
require_relative 'leopard/errors'
