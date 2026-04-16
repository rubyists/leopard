# frozen_string_literal: true

module Rubyists
  module Leopard
    class NatsJetstreamCallbacks
      def initialize(logger:)
        @logger = logger
      end

      def callbacks_for(endpoint)
        {
          on_success: method(:ack_message),
          on_failure: ->(wrapper, result) { nak_message(wrapper, result, endpoint) },
          on_error: method(:term_message),
        }
      end

      private

      def ack_message(wrapper, _result)
        wrapper.raw.ack
      end

      def nak_message(wrapper, result, endpoint)
        log_failure(result.failure)
        return wrapper.raw.nak unless endpoint.nak_delay

        wrapper.raw.nak(delay: endpoint.nak_delay)
      end

      def term_message(wrapper, error)
        @logger.error 'Unhandled JetStream error: ', error
        wrapper.raw.term
      end

      def log_failure(failure)
        @logger.error 'Error processing message: ', failure
      end
    end
  end
end
