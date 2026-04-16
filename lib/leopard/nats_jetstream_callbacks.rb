# frozen_string_literal: true

module Rubyists
  module Leopard
    # Maps Leopard handler outcomes to JetStream ack, nak, and term operations.
    class NatsJetstreamCallbacks
      # Builds a callback set for JetStream message outcomes.
      #
      # @param logger [#error] Logger used for failures and unhandled exceptions.
      #
      # @return [void]
      def initialize(logger:)
        @logger = logger
      end

      # Returns transport callbacks for a JetStream endpoint.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration being consumed.
      #
      # @return [Hash{Symbol => #call}] Outcome callbacks keyed by `:on_success`, `:on_failure`, and `:on_error`.
      def callbacks_for(endpoint)
        {
          on_success: method(:ack_message),
          on_failure: ->(wrapper, result) { nak_message(wrapper, result, endpoint) },
          on_error: method(:term_message),
        }
      end

      private

      # Acknowledges a successfully processed JetStream message.
      #
      # @param wrapper [MessageWrapper] Wrapped JetStream message.
      # @param _result [Dry::Monads::Success] Successful handler result.
      #
      # @return [void]
      def ack_message(wrapper, _result)
        wrapper.raw.ack
      end

      # Negatively acknowledges a failed JetStream message, optionally delaying redelivery.
      #
      # @param wrapper [MessageWrapper] Wrapped JetStream message.
      # @param result [Dry::Monads::Failure] Failed handler result.
      # @param endpoint [NatsJetstreamEndpoint] Endpoint configuration for the message.
      #
      # @return [void]
      def nak_message(wrapper, result, endpoint)
        log_failure(result.failure)
        return wrapper.raw.nak unless endpoint.nak_delay

        wrapper.raw.nak(delay: endpoint.nak_delay)
      end

      # Terminates a JetStream message after an unhandled exception.
      #
      # @param wrapper [MessageWrapper] Wrapped JetStream message.
      # @param error [StandardError] The unhandled exception.
      #
      # @return [void]
      def term_message(wrapper, error)
        @logger.error 'Unhandled JetStream error: ', error
        wrapper.raw.term
      end

      # Logs the failure payload returned by a handler.
      #
      # @param failure [Object] The failure payload from the handler.
      #
      # @return [void]
      def log_failure(failure)
        @logger.error 'Error processing message: ', failure
      end
    end
  end
end
