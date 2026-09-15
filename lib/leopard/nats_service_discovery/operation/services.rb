# frozen_string_literal: true

require 'trailblazer/operation'
require_relative 'discovery_options'
require_relative 'info'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Builds service-list summaries from `$SRV.INFO` responses.
        #
        # On success, the result exposes `:responses` and `:services`.
        class Services < Trailblazer::Operation
          include DiscoveryOptions

          step :load_info?
          step :summarize

          # Loads raw service info responses for summarization.
          #
          # @param ctx [Hash] Operation context.
          #
          # @return [Boolean] Whether service info was loaded.
          def load_info?(ctx, **)
            result = Info.call(**operation_options(ctx))
            ctx[:error] = result[:error] unless result.success?
            ctx[:responses] = result[:responses]
            result.success?
          end

          # Builds compact service summaries from raw info responses.
          #
          # @param ctx [Hash] Operation context.
          # @param responses [Array<Hash>] Parsed `$SRV.INFO` responses.
          #
          # @return [Array<Hash>] Service summary rows.
          def summarize(ctx, responses:, **)
            ctx[:services] = responses.map do |service|
              {
                'name' => service['name'],
                'id' => service['id'],
                'version' => service['version'],
                'endpoints' => Array(service['endpoints']).size,
              }
            end
          end
        end
      end
    end
  end
end
