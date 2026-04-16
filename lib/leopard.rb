# frozen_string_literal: true

require 'dry/configurable'
require 'pathname'
require 'semantic_logger'

##
# Namespace for Leopard and related helper extensions.
class Pathname
  # Joins the receiver with another path fragment.
  #
  # @param other [#to_s] The path fragment to append.
  #
  # @return [Pathname] The combined path.
  def /(other)
    join other.to_s
  end
end

##
# Top-level namespace for Rubyists gems.
module Rubyists
  ##
  # Namespace for Leopard runtime, DSL, and support classes.
  module Leopard
  end
end

require_relative 'leopard/settings'
require_relative 'leopard/version'
require_relative 'leopard/errors'
require_relative 'leopard/message_processor'
require_relative 'leopard/nats_jetstream_endpoint'
require_relative 'leopard/nats_jetstream_callbacks'
require_relative 'leopard/nats_jetstream_consumer'
require_relative 'leopard/nats_request_reply_callbacks'
