# frozen_string_literal: true

require 'trailblazer/operation'
require_relative '../../nats_service_discovery'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Collects and parses JSON replies for an arbitrary Service API subject.
        #
        # On success, the result exposes `:responses`.
        # On failure, the result exposes `:error`.
        class Collect < Trailblazer::Operation
          step :collect

          # Collects JSON replies from `subject`.
          #
          # @param ctx [Hash] Operation context.
          # @param client [NATS::Client] Connected NATS client.
          # @param subject [String] Service API subject to query.
          # @param timeout [Numeric] Idle timeout while waiting for replies.
          #
          # @return [Boolean] Whether replies were collected successfully.
          def collect(ctx, client:, subject:, timeout: DEFAULT_TIMEOUT, **)
            ctx[:responses] = NatsServiceDiscovery.new(client:).send(:collect_json, subject, timeout:)
          rescue StandardError => e
            ctx[:error] = e
            false
          end
        end
      end
    end
  end
end
