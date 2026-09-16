# frozen_string_literal: true

require 'trailblazer/operation'
require_relative '../../nats_service_discovery'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Base class for `$SRV.<VERB>` operations.
        #
        # Subclasses choose which Service API verb to invoke.
        class Verb < Trailblazer::Operation
          step :collect

          # Collects responses for the subclass Service API verb.
          #
          # @param ctx [Hash] Operation context.
          #
          # @return [Boolean] Whether responses were collected successfully.
          def collect(ctx, **)
            discovery = NatsServiceDiscovery.new(client: ctx[:client], prefix: ctx[:prefix] || DEFAULT_PREFIX)
            ctx[:responses] = public_send_verb(
              discovery,
              name: ctx[:name],
              id: ctx[:id],
              timeout: ctx[:timeout] || DEFAULT_TIMEOUT,
            )
          rescue StandardError => e
            ctx[:error] = e
            false
          end

          private

          # Invokes the subclass-specific discovery method.
          #
          # @raise [NotImplementedError] when a subclass does not implement this.
          def public_send_verb(_discovery, **)
            raise NotImplementedError, "#{self.class} must define #public_send_verb"
          end
        end
      end
    end
  end
end
