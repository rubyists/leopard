# frozen_string_literal: true

require 'nats/client'
require 'trailblazer/operation'
require_relative '../../nats_service_discovery'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Opens a NATS client connection for discovery operations.
        #
        # On success, the result exposes `:client`.
        # On failure, the result exposes `:error`.
        class Connect < Trailblazer::Operation
          step :connect

          # Connects to NATS using `:server` or `:nats_url`.
          #
          # @param ctx [Hash] Operation context.
          #
          # @return [Boolean] Whether the connection was opened.
          def connect(ctx, **)
            opts = (ctx[:connect_options] || {}).dup
            opts[:user_credentials] = ctx[:creds] if ctx[:creds]
            ctx[:client] = NATS.connect(connection_url(ctx), opts)
          rescue StandardError => e
            ctx[:error] = e
            false
          end

          private

          # Default NATS URL used when no URL is provided.
          #
          # @return [String]
          def default_url
            ENV.fetch('NATS_URL', 'nats://127.0.0.1:4222')
          end

          # Resolves the NATS URL from the operation context.
          #
          # @param ctx [Hash] Operation context.
          #
          # @return [String]
          def connection_url(ctx)
            ctx[:nats_url] || ctx[:server] || default_url
          end
        end
      end
    end
  end
end
