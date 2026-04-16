# frozen_string_literal: true

require_relative '../helper'
require Rubyists::Leopard.libroot / 'leopard/nats_api_server'
require Rubyists::Leopard.libroot / 'leopard/message_processor'

describe 'Rubyists::Leopard::NatsApiServer' do # rubocop:disable Metrics/BlockLength
  before do
    @klass = Class.new do
      include Rubyists::Leopard::NatsApiServer
    end

    # Create an instance of the class to test instance methods
    @instance = @klass.new

    mod = Rubyists::Leopard::NatsApiServer
    cm  = mod::ClassMethods
    cm.const_set(:Success, mod::Success) unless cm.const_defined?(:Success)
    cm.const_set(:Failure, mod::Failure) unless cm.const_defined?(:Failure)
    @logger = Object.new
    @logger.define_singleton_method(:error) { |*| nil }
  end

  it 'registers an endpoint' do
    blk = proc {}
    @klass.endpoint(:foo, &blk)

    assert_equal 1, @klass.endpoints.length
    endpoint = @klass.endpoints.first

    assert_equal :foo, endpoint.name
    assert_equal :foo, endpoint.subject
    assert_nil endpoint.queue
    assert_nil endpoint.group
    assert_equal blk, endpoint.handler
  end

  it 'registers an endpoint with options' do
    blk = proc {}
    @klass.endpoint(:foo, subject: 'bar', queue: 'q', &blk)

    assert_equal 1, @klass.endpoints.length
    endpoint = @klass.endpoints.first

    assert_equal :foo, endpoint.name
    assert_equal 'bar', endpoint.subject
    assert_equal 'q', endpoint.queue
    assert_nil endpoint.group
    assert_equal blk, endpoint.handler
  end

  it 'registers a jetstream endpoint with options' do
    blk = proc {}
    @klass.jetstream_endpoint(
      :events,
      stream: 'EVENTS',
      subject: 'events.created',
      durable: 'events-consumer',
      consumer: { max_deliver: 5 },
      batch: 10,
      fetch_timeout: 2,
      nak_delay: 1,
      &blk
    )

    assert_equal 1, @klass.jetstream_endpoints.length
    endpoint = @klass.jetstream_endpoints.first

    assert_equal :events, endpoint.name
    assert_equal 'EVENTS', endpoint.stream
    assert_equal 'events.created', endpoint.subject
    assert_equal 'events-consumer', endpoint.durable
    assert_equal({ max_deliver: 5 }, endpoint.consumer)
    assert_equal 10, endpoint.batch
    assert_equal 2, endpoint.fetch_timeout
    assert_equal 1, endpoint.nak_delay
    assert_equal blk, endpoint.handler
  end

  it 'registers a group' do
    @klass.group :math, queue: 'math'

    assert_equal({ math: { name: :math, parent: nil, queue: 'math' } }, @klass.groups)
  end

  it 'registers an endpoint with a group' do
    blk = proc {}
    @klass.group :math
    @klass.endpoint(:add, group: :math, &blk)

    assert_equal 1, @klass.endpoints.length
    endpoint = @klass.endpoints.first

    assert_equal :add, endpoint.name
    assert_equal :add, endpoint.subject
    assert_nil endpoint.queue
    assert_equal :math, endpoint.group
    assert_equal blk, endpoint.handler
  end

  it 'adds middleware' do
    blk = proc {}
    @klass.use(String, 1, &blk)

    assert_equal [[String, [1], blk]], @klass.middleware
  end

  it 'dispatches through middleware in reverse order' do # rubocop:disable Metrics/BlockLength
    order = []
    mw1 = Class.new do
      def initialize(app) = (@app = app)

      def call(wrapper)
        wrapper.log << :mw1
        @app.call(wrapper)
      end
    end
    mw2 = Class.new do
      def initialize(app) = (@app = app)

      def call(wrapper)
        wrapper.log << :mw2
        @app.call(wrapper)
      end
    end
    @klass.use mw1
    @klass.use mw2

    @instance = @klass.new

    raw = Struct.new(:data, :header).new('raw_message', {})
    wrapper = Struct.new(:raw, :log).new(raw, order)

    handler = proc { |wrapper|
      wrapper.log << :handler
      Dry::Monads::Success(:ok)
    }
    processor = Rubyists::Leopard::MessageProcessor.new(
      wrapper_factory: ->(*) { wrapper },
      middleware: -> { @klass.middleware },
      execute_handler: ->(message, block) { block.call(message) },
      logger: @logger,
    )
    processor.process(raw, handler, on_success: ->(*_) {}, on_failure: ->(*_) {}, on_error: ->(*_) {})

    assert_equal %i[mw1 mw2 handler], order
  end

  it 'executes a handler and routes Success to the success callback' do
    result = Dry::Monads::Success(:ok)
    wrapper = Object.new
    success = nil
    processor = processor_for(wrapper:, result:)

    processor.process(:raw, proc { |message| message }, callback_set(on_success: ->(message, value) { success = [message, value] }))

    assert_equal [wrapper, result], success
  end

  it 'routes raised errors to the error callback' do
    err = nil
    wrapper = Object.new
    processor = Rubyists::Leopard::MessageProcessor.new(
      wrapper_factory: ->(*) { wrapper },
      middleware: -> { [] },
      execute_handler: ->(*) { raise 'boom' },
      logger: @logger,
    )
    processor.process(:raw, proc {}, callback_set(on_error: ->(_message, raised) { err = raised }))

    assert_instance_of RuntimeError, err
    assert_equal 'boom', err.message
  end

  it 'routes Success results unchanged to the success callback' do
    wrapper = Minitest::Mock.new
    on_success = Minitest::Mock.new
    result = Rubyists::Leopard::NatsApiServer::Success.new('ok')
    on_success.expect(:call, nil, [wrapper, result])
    processor_for(wrapper:, result:).process(:raw, proc { |message| message }, callback_set(on_success:, on_failure: ->(*_) {}))
    on_success.verify
  end

  it 'routes Failure results unchanged to the failure callback' do
    wrapper = Minitest::Mock.new
    on_failure = Minitest::Mock.new
    result = Rubyists::Leopard::NatsApiServer::Failure.new('fail')
    on_failure.expect(:call, nil, [wrapper, result])
    processor_for(wrapper:, result:).process(:raw, proc { |message| message }, callback_set(on_success: ->(*_) {}, on_failure:))
    on_failure.verify
  end

  it 'passes hash failures through unchanged' do
    err = { code: 422, description: 'invalid' }
    wrapper = Object.new
    result = Rubyists::Leopard::NatsApiServer::Failure.new(err)
    received = nil
    processor_for(wrapper:, result:).process(
      :raw,
      proc { |message| message },
      callback_set(on_success: ->(*_) {}, on_failure: ->(_wrapper, failure_result) { received = failure_result.failure }),
    )

    assert_equal err, received
  end

  def processor_for(wrapper:, result:)
    Rubyists::Leopard::MessageProcessor.new(
      wrapper_factory: ->(*) { wrapper },
      middleware: -> { [] },
      execute_handler: ->(*) { result },
      logger: @logger,
    )
  end

  def callback_set(on_success: ->(*_) {}, on_failure: ->(*_) {}, on_error: ->(*_) {})
    { on_success:, on_failure:, on_error: }
  end

  describe 'prometheus metrics' do # rubocop:disable Metrics/BlockLength
    let(:available_struct) { Struct.new(:zero?) { def available_permits = self } }
    let(:queue_struct) { Struct.new(:pending_size) { def size = pending_size } }
    let(:handler_struct) { Struct.new(:concurrency_semaphore, :pending_queue) }
    let(:endpoint_struct) do
      Struct.new(:subject) do
        def initialize(subject, handler)
          super(subject)
          @handler = handler
        end
      end
    end
    let(:service_struct) { Struct.new(:endpoints) }
    let(:worker_struct) do
      Struct.new(:service) do
        def instance_variable_get(name)
          return service if name == :@service

          super
        end
      end
    end
    let(:expected_metrics) do
      <<~METRICS
        # HELP leopard_subject_busy_instances Instances currently processing a message on this subject
        # TYPE leopard_subject_busy_instances gauge
        leopard_subject_busy_instances{subject="alpha"} 1
        leopard_subject_busy_instances{subject="beta"} 0

        # HELP leopard_subject_total_instances Total Leopard instances in this process
        # TYPE leopard_subject_total_instances gauge
        leopard_subject_total_instances{subject="alpha"} 2
        leopard_subject_total_instances{subject="beta"} 2

        # HELP leopard_subject_pending_messages Messages pending processing across all instances
        # TYPE leopard_subject_pending_messages gauge
        leopard_subject_pending_messages{subject="alpha"} 5
        leopard_subject_pending_messages{subject="beta"} 1
      METRICS
    end

    it 'renders prometheus metrics from the erb template' do
      workers = [
        worker_struct.new(service_struct.new([
          endpoint_struct.new('alpha', handler_struct.new(available_struct.new(true), queue_struct.new(3))),
          endpoint_struct.new('beta', handler_struct.new(available_struct.new(false), queue_struct.new(1))),
        ])),
        worker_struct.new(service_struct.new([
          endpoint_struct.new('alpha', handler_struct.new(available_struct.new(false), queue_struct.new(2))),
        ])),
      ]

      assert_equal expected_metrics, @klass.send(:prometheus_metrics, workers)
    end
  end
end
