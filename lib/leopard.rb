# frozen_string_literal: true

require 'dry/configurable'
require 'pathname'
require 'semantic_logger'

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
require_relative 'leopard/message_processor'
require_relative 'leopard/nats_jetstream_endpoint'
require_relative 'leopard/nats_jetstream_callbacks'
require_relative 'leopard/nats_jetstream_consumer'
require_relative 'leopard/nats_request_reply_callbacks'
