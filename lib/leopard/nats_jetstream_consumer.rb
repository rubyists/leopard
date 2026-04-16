# frozen_string_literal: true

require_relative 'nats_jetstream_callbacks'
require_relative 'nats_jetstream_endpoint'

module Rubyists
  module Leopard
    class NatsJetstreamConsumer
      attr_reader :subscriptions, :threads

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

      def start
        @running = true
        @endpoints.each { |endpoint| start_endpoint(endpoint) }
      end

      def stop
        @running = false
        subscriptions.each(&:unsubscribe)
        threads.each(&:join)
      end

      private

      def start_endpoint(endpoint)
        subscription = build_subscription(endpoint)
        subscriptions << subscription
        threads << @thread_factory.new { consume_endpoint(subscription, endpoint) }
      end

      def build_subscription(endpoint)
        ensure_consumer(endpoint)
        @jetstream.pull_subscribe(
          endpoint.subject,
          endpoint.durable,
          stream: endpoint.stream,
        )
      end

      def ensure_consumer(endpoint)
        @jetstream.consumer_info(endpoint.stream, endpoint.durable)
      rescue NATS::JetStream::Error::NotFound
        @jetstream.add_consumer(endpoint.stream, consumer_config(endpoint))
      end

      def consumer_config(endpoint)
        base = {
          durable_name: endpoint.durable,
          filter_subject: endpoint.subject,
          ack_policy: 'explicit',
        }
        base.merge(normalized_consumer_options(endpoint))
      end

      def normalized_consumer_options(endpoint)
        return {} unless endpoint.consumer
        return endpoint.consumer.to_h if endpoint.consumer.respond_to?(:to_h)

        endpoint.consumer
      end

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

      def consume_batch(subscription, endpoint)
        fetch_messages(subscription, endpoint).each do |raw_msg|
          @process_message.call(raw_msg, endpoint.handler, @callbacks.callbacks_for(endpoint))
        end
      end

      def fetch_messages(subscription, endpoint)
        subscription.fetch(endpoint.batch, timeout: endpoint.fetch_timeout)
      end

      def log_loop_error(endpoint, error)
        @logger.error "JetStream endpoint #{endpoint.name} loop error: ", error
      end
    end
  end
end
