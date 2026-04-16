# frozen_string_literal: true

module Rubyists
  module Leopard
    class NatsRequestReplyCallbacks
      def initialize(logger:)
        @logger = logger
      end

      def callbacks
        {
          on_success: method(:respond_with_success),
          on_failure: method(:respond_with_failure),
          on_error: method(:respond_with_error),
        }
      end

      private

      def respond_with_success(wrapper, result)
        wrapper.respond(result.value!)
      end

      def respond_with_failure(wrapper, result)
        log_failure(result.failure)
        wrapper.respond_with_error(result.failure)
      end

      def respond_with_error(wrapper, error)
        wrapper.respond_with_error(error)
      end

      def log_failure(failure)
        @logger.error 'Error processing message: ', failure
      end
    end
  end
end
