# frozen_string_literal: true

require_relative 'nats_jetstream_callbacks'
require_relative 'nats_jetstream_endpoint'

module Rubyists
  module Leopard
    # Coordinates JetStream pull subscriptions and dispatches fetched messages through Leopard.
    class NatsJetstreamConsumer
      # Consumer configuration keys Leopard owns and will not allow endpoint overrides to replace.
      PROTECTED_CONSUMER_KEYS = %i[durable_name filter_subject ack_policy].freeze

      # @!attribute [r] subscriptions
      #   @return [Array<Object>] Active JetStream pull subscriptions.
      # @!attribute [r] threads
      #   @return [Array<Thread>] Consumer loop threads for each endpoint.
      attr_reader :subscriptions, :threads

      # Builds a pull-consumer coordinator for one Leopard worker.
      #
      # @param jetstream [Object] JetStream client used to manage consumers and subscriptions.
      # @param endpoints [Array<NatsJetstreamEndpoint>] JetStream endpoint definitions for this worker.
      # @param logger [#error] Logger used for loop failures.
      # @param process_message [#call] Callable that processes a raw JetStream message through Leopard.
      # @param dependencies [Hash{Symbol => Object}] Optional collaborators for callback and thread creation.
      # @option dependencies [Class] :callback_builder (NatsJetstreamCallbacks) Builder for transport callbacks.
      # @option dependencies [Class] :thread_factory (Thread) Thread-like factory used to spawn consumer loops.
      # @return [void]
      def initialize(jetstream:, endpoints:, logger:, process_message:, **dependencies)
        @jetstream = jetstream
        @endpoints = endpoints
        @logger = logger
        @process_message = process_message
        @callbacks = dependencies.fetch(:callback_builder, NatsJetstreamCallbacks).new(logger:)
        @thread_factory = dependencies.fetch(:thread_factory, Thread)
        @subscriptions = []
        @threads = []
        @running = false
      end

      # Starts one pull-consumer loop per configured endpoint.
      #
      # @return [void]
      def start
        @running = true
        @endpoints.each { |endpoint| start_endpoint(endpoint) }
      end

      # Stops all pull-consumer loops and waits for them to exit.
      #
      # @return [void]
      def stop
        @running = false
        subscriptions.each(&:unsubscribe)
        threads.each(&:join)
      end

      private

      # Starts a consumer loop for one endpoint.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration to consume.
      # @return [void]
      def start_endpoint(endpoint)
        subscription = build_subscription(endpoint)
        subscriptions << subscription
        threads << @thread_factory.new { consume_endpoint(subscription, endpoint) }
      end

      # Ensures the durable consumer exists and creates a pull subscription for it.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration to subscribe to.
      # @return [Object] The JetStream pull subscription.
      def build_subscription(endpoint)
        ensure_consumer(endpoint)
        @jetstream.pull_subscribe(
          endpoint.subject,
          endpoint.durable,
          stream: endpoint.stream,
        )
      end

      # Verifies that the durable consumer exists, creating it when missing.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration to ensure.
      # @return [Object] Consumer metadata from `consumer_info` or `add_consumer`.
      def ensure_consumer(endpoint)
        @jetstream.consumer_info(endpoint.stream, endpoint.durable)
      rescue NATS::JetStream::Error::NotFound
        @jetstream.add_consumer(endpoint.stream, consumer_config(endpoint))
      end

      # Builds the JetStream consumer configuration for an endpoint.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration to translate.
      # @return [Hash] Consumer configuration accepted by `add_consumer`.
      def consumer_config(endpoint)
        base = {
          durable_name: endpoint.durable,
          filter_subject: endpoint.subject,
          ack_policy: 'explicit',
        }
        base.merge(safe_consumer_options(endpoint))
      end

      # Normalizes optional consumer overrides into a hash.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration to inspect.
      # @return [Hash] Consumer overrides, or an empty hash when none were provided.
      def normalized_consumer_options(endpoint)
        return {} unless endpoint.consumer
        return endpoint.consumer.to_h if endpoint.consumer.respond_to?(:to_h)

        endpoint.consumer
      end

      # Removes Leopard-managed consumer keys from user overrides.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration to inspect.
      # @return [Hash] Consumer overrides excluding protected keys required by Leopard.
      def safe_consumer_options(endpoint)
        normalized_consumer_options(endpoint).reject { |key, _value| PROTECTED_CONSUMER_KEYS.include?(key.to_sym) }
      end

      # Repeatedly fetches and processes batches for one endpoint while the consumer is running.
      #
      # @param subscription [Object] Pull subscription for the endpoint.
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration being consumed.
      # @return [void]
      def consume_endpoint(subscription, endpoint)
        while @running
          begin
            consume_batch(subscription, endpoint)
          rescue NATS::Timeout
            next if @running
          rescue StandardError => e
            log_loop_error(endpoint, e)
            break unless @running
          end
        end
      end

      # Fetches one batch from JetStream and processes each message through Leopard.
      #
      # @param subscription [Object] Pull subscription for the endpoint.
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration being consumed.
      # @return [void]
      def consume_batch(subscription, endpoint)
        fetch_messages(subscription, endpoint).each do |raw_msg|
          @process_message.call(raw_msg, endpoint.handler, @callbacks.callbacks_for(endpoint))
        end
      end

      # Fetches a batch of messages for one endpoint.
      #
      # @param subscription [Object] Pull subscription for the endpoint.
      # @param endpoint [NatsJetstreamEndpoint] The endpoint configuration being consumed.
      # @return [Array<Object>] Raw JetStream messages returned by the subscription.
      def fetch_messages(subscription, endpoint)
        subscription.fetch(endpoint.batch, timeout: endpoint.fetch_timeout)
      end

      # Logs an endpoint-level loop failure.
      #
      # @param endpoint [NatsJetstreamEndpoint] The endpoint whose loop failed.
      # @param error [StandardError] The raised exception.
      # @return [void]
      def log_loop_error(endpoint, error)
        @logger.error "JetStream endpoint #{endpoint.name} loop error: ", error
      end
    end
  end
end
