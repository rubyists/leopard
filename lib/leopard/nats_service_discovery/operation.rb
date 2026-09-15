# frozen_string_literal: true

require_relative '../nats_service_discovery'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      # Trailblazer operations for NATS Service API discovery workflows.
      module Operation
      end
    end
  end
end

require_relative 'operation/discovery_options'
require_relative 'operation/connect'
require_relative 'operation/collect'
require_relative 'operation/verb'
require_relative 'operation/ping'
require_relative 'operation/info'
require_relative 'operation/stats'
require_relative 'operation/services'
require_relative 'operation/subject_map'
