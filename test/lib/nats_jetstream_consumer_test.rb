# frozen_string_literal: true

require_relative '../helper'
require Rubyists::Leopard.libroot / 'leopard/nats_jetstream_consumer'
require Rubyists::Leopard.libroot / 'leopard/nats_jetstream_endpoint'

class NatsJetstreamConsumerTest < Minitest::Test
  def setup
    @consumer = Rubyists::Leopard::NatsJetstreamConsumer.new(
      jetstream: Object.new,
      endpoints: [],
      logger: Object.new,
      process_message: ->(*_) {},
    )
  end

  def test_consumer_config_preserves_durable_name
    assert_equal 'events-consumer', symbol_key_config[:durable_name]
  end

  def test_consumer_config_preserves_filter_subject
    assert_equal 'events.created', symbol_key_config[:filter_subject]
  end

  def test_consumer_config_preserves_explicit_ack_policy
    assert_equal 'explicit', symbol_key_config[:ack_policy]
  end

  def test_consumer_config_keeps_safe_symbol_key_overrides
    assert_equal 30, symbol_key_config[:ack_wait]
    assert_equal 5, symbol_key_config[:max_deliver]
  end

  def test_consumer_config_strips_protected_string_keys
    refute_includes string_key_config.keys, 'durable_name'
    refute_includes string_key_config.keys, 'filter_subject'
    refute_includes string_key_config.keys, 'ack_policy'
  end

  def test_consumer_config_keeps_safe_string_key_overrides
    assert_equal 100, string_key_config['max_ack_pending']
  end

  private

  def symbol_key_config
    @symbol_key_config ||= @consumer.send(:consumer_config, endpoint_with_consumer(symbol_key_overrides))
  end

  def string_key_config
    @string_key_config ||= @consumer.send(:consumer_config, endpoint_with_consumer(string_key_overrides))
  end

  def endpoint_with_consumer(consumer)
    Rubyists::Leopard::NatsJetstreamEndpoint.new(**base_endpoint_attributes, consumer:)
  end

  def symbol_key_overrides
    {
      durable_name: 'override-durable',
      filter_subject: 'override.subject',
      ack_policy: 'none',
      ack_wait: 30,
      max_deliver: 5,
    }
  end

  def string_key_overrides
    {
      'durable_name' => 'override-durable',
      'filter_subject' => 'override.subject',
      'ack_policy' => 'none',
      'max_ack_pending' => 100,
    }
  end

  def base_endpoint_attributes
    {
      name: :events, stream: 'EVENTS', subject: 'events.created', durable: 'events-consumer',
      batch: 1, fetch_timeout: 1, nak_delay: nil, handler: proc {}
    }
  end
end
