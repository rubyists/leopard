#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/leopard/nats_api_server'

# Example JetStream worker for async event processing.
class EventConsumer
  include Rubyists::Leopard::NatsApiServer

  config.logger = SemanticLogger[:EventConsumer]

  jetstream_endpoint(
    :events,
    stream: 'EVENTS',
    subject: 'events.created',
    durable: 'events-created-worker',
    consumer: {
      ack_wait: 30,
      max_deliver: 5,
    },
    batch: 5,
    fetch_timeout: 1,
    nak_delay: 2,
  ) do |msg|
    logger.info 'Processing event', data: msg.data
    Success(msg.data)
  rescue StandardError => e
    Failure(error: e.message, data: msg.data)
  end
end

if __FILE__ == $PROGRAM_NAME
  SemanticLogger.default_level = :info
  SemanticLogger.add_signal_handler
  SemanticLogger.add_appender(io: $stdout, formatter: :color)
  EventConsumer.run(
    nats_url: 'nats://localhost:4222',
    service_opts: {
      name: 'example.event_consumer',
      version: '1.0.0',
    },
    instances: ENV.fetch('EVENT_CONSUMER_INSTANCES', '1').to_i,
  )
end
