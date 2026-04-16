# frozen_string_literal: true

module Rubyists
  module Leopard
    class MessageProcessor
      def initialize(wrapper_factory:, middleware:, execute_handler:, logger:)
        @wrapper_factory = wrapper_factory
        @middleware = middleware
        @execute_handler = execute_handler
        @logger = logger
      end

      def process(raw_msg, handler, callbacks)
        app(callbacks, handler).call(@wrapper_factory.call(raw_msg))
      end

      private

      def app(callbacks, handler)
        @middleware.call.reverse_each.reduce(base_app(handler, callbacks)) do |current, (klass, args, blk)|
          klass.new(current, *args, &blk)
        end
      end

      def base_app(handler, callbacks)
        lambda do |wrapper|
          result = @execute_handler.call(wrapper, handler)
          process_result(wrapper, result, callbacks)
        rescue StandardError => e
          @logger.error 'Error processing message: ', e
          callbacks[:on_error].call(wrapper, e)
        end
      end

      def process_result(wrapper, result, callbacks)
        case result
        in Dry::Monads::Success
          callbacks[:on_success].call(wrapper, result)
        in Dry::Monads::Failure
          callbacks[:on_failure].call(wrapper, result)
        else
          @logger.error('Unexpected result: ', result:)
          raise ResultError, "Unexpected Response from Handler, must respond with a Success or Failure monad: #{result}"
        end
      end
    end
  end
end
