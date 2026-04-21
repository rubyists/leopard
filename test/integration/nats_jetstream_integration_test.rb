# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'timeout'
require_relative '../helper'
require Rubyists::Leopard.libroot / 'leopard/nats_api_server'

module NatsJetstreamBrokerHelpers
  NATS_URL = ENV.fetch('LEOPARD_NATS_URL', ENV.fetch('NATS_URI', 'nats://127.0.0.1:4222'))
  WAIT_TIMEOUT = 5
  NO_REDELIVERY_TIMEOUT = 1.5

  private

  def setup_integration_context
    @workers = []
    @streams = []
    @service_classes = []
    skip 'NATS JetStream broker not available' unless jetstream_available?

    @client = NATS.connect(**nats_connect_options)
    @jetstream = @client.jetstream
  end

  def teardown_integration_context
    @workers.reverse_each(&:stop)
    @streams.reverse_each { |stream| @jetstream&.delete_stream(stream) }
    @service_classes.reverse_each { |klass| remove_service_class(klass) }
    @client&.close
  end

  def jetstream_available?
    nc = NATS.connect(**nats_connect_options)
    nc.jetstream.account_info
    nc.close
    true
  rescue StandardError
    false
  end

  def build_names
    token = SecureRandom.hex(4)
    {
      stream: "EVENTS_#{token}",
      subject: "events.#{token}",
      durable: "events_consumer_#{token}",
      service: "JetstreamService#{token}",
    }
  end

  def publish(subject, payload)
    @jetstream.publish(subject, JSON.generate(payload))
  end

  def pop_event(queue, timeout: WAIT_TIMEOUT)
    Timeout.timeout(timeout) { queue.pop }
  end

  def refute_event(queue, timeout: NO_REDELIVERY_TIMEOUT)
    Timeout.timeout(timeout) { queue.pop }

    flunk 'expected no additional JetStream delivery'
  rescue Timeout::Error
    nil
  end

  def wait_for(timeout: WAIT_TIMEOUT)
    Timeout.timeout(timeout) do
      loop do
        return if yield

        sleep 0.05
      end
    end
  end

  def nats_connect_options
    {
      uri: NATS_URL,
      reconnect: false,
      connect_timeout: 0.5,
      max_reconnect_attempts: 0,
    }
  end
end

module NatsJetstreamServiceHelpers
  private

  def build_worker(names, middleware: nil, &handler)
    create_stream(names)
    klass = build_service_class(names, middleware:, &handler)
    worker = klass.new
    worker.setup_worker(
      nats_url: NatsJetstreamBrokerHelpers::NATS_URL,
      service_opts: { name: names[:service], version: '1.0.0' },
    )
    wait_for_consumer(names)
    @workers << worker
    worker
  end

  def create_stream(names)
    @jetstream.add_stream(name: names[:stream], subjects: [names[:subject]])
    @streams << names[:stream]
  end

  def build_service_class(names, middleware: nil, &handler)
    klass = Class.new do
      include Rubyists::Leopard::NatsApiServer

      config.logger = SemanticLogger[:JetstreamIntegration]
    end
    self.class.const_set(names[:service], klass)
    @service_classes << klass
    klass.use(middleware) if middleware
    klass.jetstream_endpoint(:events, **endpoint_options(names), &handler)
    klass
  end

  def endpoint_options(names)
    {
      stream: names[:stream],
      subject: names[:subject],
      durable: names[:durable],
      consumer: { ack_wait: 1, max_deliver: 5 },
      batch: 1,
      fetch_timeout: 0.25,
      nak_delay: 1,
    }
  end

  def build_tracking_middleware(queue)
    Class.new do
      define_method(:initialize) { |app| @app = app }
      define_method(:call) do |wrapper|
        queue << :middleware
        @app.call(wrapper)
      end
    end
  end

  def wait_for_consumer(names)
    wait_for do
      @jetstream.consumer_info(names[:stream], names[:durable])
      true
    rescue NATS::JetStream::Error::NotFound
      false
    end
  end

  def remove_service_class(klass)
    self.class.send(:remove_const, klass.name.split('::').last)
  rescue NameError
    nil
  end
end

class NatsJetstreamSuccessIntegrationTest < Minitest::Test
  include NatsJetstreamBrokerHelpers
  include NatsJetstreamServiceHelpers

  def setup
    setup_integration_context
  end

  def teardown
    teardown_integration_context
  end

  def test_success_acks_once_and_runs_middleware
    tracker, names = build_success_flow

    publish(names[:subject], { ok: true })

    assert_success_flow(tracker)
  end

  private

  def build_success_flow
    tracker = Queue.new
    names = build_names
    middleware = build_tracking_middleware(tracker)
    build_worker(names, middleware:, &success_handler(tracker))
    [tracker, names]
  end

  def success_handler(tracker)
    lambda do |msg|
      tracker << [:handler, msg.class.name, msg.raw.metadata.num_delivered]
      Dry::Monads::Success(msg.data)
    end
  end

  def assert_success_flow(tracker)
    assert_equal :middleware, pop_event(tracker)
    assert_equal [:handler, 'Rubyists::Leopard::MessageWrapper', 1], pop_event(tracker)
    refute_event(tracker)
  end
end

class NatsJetstreamRetryIntegrationTest < Minitest::Test
  include NatsJetstreamBrokerHelpers
  include NatsJetstreamServiceHelpers

  def setup
    setup_integration_context
  end

  def teardown
    teardown_integration_context
  end

  def test_failure_naks_and_redelivers
    attempts, names = build_retry_flow

    publish(names[:subject], { ok: false })

    assert_redelivery(attempts)
  end

  def test_exception_terms_without_redelivery
    attempts = Queue.new
    names = build_names
    build_worker(names) do |msg|
      attempts << msg.raw.metadata.num_delivered
      raise 'boom'
    end
    publish(names[:subject], { ok: false })

    assert_equal 1, pop_event(attempts)
    refute_event(attempts)
  end

  private

  def build_retry_flow
    attempts = Queue.new
    names = build_names
    build_worker(names, &retry_handler(attempts))
    [attempts, names]
  end

  def retry_handler(attempts)
    lambda do |msg|
      attempts << msg.raw.metadata.num_delivered
      return Dry::Monads::Failure('retry') if msg.raw.metadata.num_delivered == 1

      Dry::Monads::Success(msg.data)
    end
  end

  def assert_redelivery(attempts)
    assert_equal 1, pop_event(attempts)
    assert_equal 2, pop_event(attempts)
  end
end
