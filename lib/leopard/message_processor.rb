# frozen_string_literal: true

module Rubyists
  module Leopard
    # Composes middleware around Leopard handlers and routes their results to transport callbacks.
    class MessageProcessor
      private attr_reader :execute_handler, :logger, :middleware, :wrapper_factory

      # Builds a reusable processor for request/reply and JetStream transports.
      #
      # @param wrapper_factory [#call] Callable that wraps a raw transport message in a {MessageWrapper}-compatible object.
      # @param middleware [#call] Callable returning the current middleware stack.
      # @param execute_handler [#call] Callable that executes the endpoint handler with the wrapped message.
      # @param logger [#error] Logger used for processing failures.
      # @return [void]
      def initialize(wrapper_factory:, middleware:, execute_handler:, logger:)
        @wrapper_factory = wrapper_factory
        @middleware = middleware
        @execute_handler = execute_handler
        @logger = logger
      end

      # Processes a raw transport message through middleware and terminal callbacks.
      #
      # @param raw_msg [Object] The raw transport message from NATS.
      # @param handler [Proc] The endpoint handler to execute.
      # @param callbacks [Hash{Symbol => #call}] Success, failure, and error callbacks for the transport.
      # @return [Object] The transport-specific callback result.
      def process(raw_msg, handler, callbacks)
        app(callbacks, handler).call(wrapper_factory.call(raw_msg))
      end

      private

      # Builds the middleware stack around the terminal application.
      #
      # @param callbacks [Hash{Symbol => #call}] Transport callbacks keyed by outcome.
      # @param handler [Proc] The endpoint handler to execute at the core of the stack.
      # @return [#call] The composed middleware application.
      def app(callbacks, handler)
        middleware.call.reverse_each.reduce(base_app(handler, callbacks)) do |current, (klass, args, blk)|
          klass.new(current, *args, &blk)
        end
      end

      # Builds the terminal application that runs the handler and dispatches transport callbacks.
      #
      # @param handler [Proc] The endpoint handler to execute.
      # @param callbacks [Hash{Symbol => #call}] Transport callbacks keyed by outcome.
      # @return [Proc] The terminal application for the middleware chain.
      def base_app(handler, callbacks)
        lambda do |wrapper|
          result = execute_handler.call(wrapper, handler)
          process_result(wrapper, result, callbacks)
        rescue StandardError => e
          logger.error 'Error processing message: ', e
          callbacks[:on_error].call(wrapper, e)
        end
      end

      # Routes a {Dry::Monads::Result} to the appropriate transport callback.
      #
      # @param wrapper [MessageWrapper] The wrapped transport message.
      # @param result [Dry::Monads::Result] The handler result to route.
      # @param callbacks [Hash{Symbol => #call}] Transport callbacks keyed by outcome.
      # @return [Object] The callback return value for the routed result.
      # @raise [ResultError] If the handler returned a non-result object.
      def process_result(wrapper, result, callbacks)
        case result
        in Dry::Monads::Success
          callbacks[:on_success].call(wrapper, result)
        in Dry::Monads::Failure
          callbacks[:on_failure].call(wrapper, result)
        else
          logger.error('Unexpected result: ', result:)
          raise ResultError, "Unexpected Response from Handler, must respond with a Success or Failure monad: #{result}"
        end
      end
    end
  end
end
