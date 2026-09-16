# frozen_string_literal: true

require_relative '../../nats_service_discovery'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Shared option extraction for operations that compose other discovery operations.
        module DiscoveryOptions
          private

          # Extracts the common discovery options from a Trailblazer context.
          #
          # @param ctx [Hash] Operation context.
          #
          # @return [Hash] Arguments suitable for another discovery operation.
          def operation_options(ctx)
            {
              client: ctx[:client],
              prefix: ctx[:prefix],
              timeout: ctx[:timeout],
              name: ctx[:name],
              id: ctx[:id],
            }
          end
        end
      end
    end
  end
end
