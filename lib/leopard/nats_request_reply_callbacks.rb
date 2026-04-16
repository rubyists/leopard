# frozen_string_literal: true

module Rubyists
  module Leopard
    # Maps Leopard handler outcomes to request/reply response behavior.
    class NatsRequestReplyCallbacks
      # Builds a callback set for request/reply endpoint outcomes.
      #
      # @param logger [#error] Logger used for failure payloads.
      #
      # @return [void]
      def initialize(logger:)
        @logger = logger
      end

      # Returns transport callbacks for request/reply endpoints.
      #
      # @return [Hash{Symbol => #call}] Outcome callbacks keyed by `:on_success`, `:on_failure`, and `:on_error`.
      def callbacks
        {
          on_success: method(:respond_with_success),
          on_failure: method(:respond_with_failure),
          on_error: method(:respond_with_error),
        }
      end

      private

      # Responds to a successful request with the handler payload.
      #
      # @param wrapper [MessageWrapper] Wrapped request message.
      # @param result [Dry::Monads::Success] Successful handler result.
      #
      # @return [void]
      def respond_with_success(wrapper, result)
        wrapper.respond(result.value!)
      end

      # Responds to a failed request with the failure payload.
      #
      # @param wrapper [MessageWrapper] Wrapped request message.
      # @param result [Dry::Monads::Failure] Failed handler result.
      #
      # @return [void]
      def respond_with_failure(wrapper, result)
        log_failure(result.failure)
        wrapper.respond_with_error(result.failure)
      end

      # Responds to a request with an exception payload after an unhandled error.
      #
      # @param wrapper [MessageWrapper] Wrapped request message.
      # @param error [StandardError] The unhandled exception.
      #
      # @return [void]
      def respond_with_error(wrapper, error)
        wrapper.respond_with_error(error)
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
