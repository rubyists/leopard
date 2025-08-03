# frozen_string_literal: true

require_relative '../helper'
require Rubyists::Leopard.libroot / 'leopard/nats_api_server'

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
    @instance.stub(:process_result, ->(_wrapper, _result) {}) do
      Rubyists::Leopard::MessageWrapper.stub(:new, wrapper) do
        @instance.send(:dispatch_with_middleware, wrapper, handler)
      end
    end

    assert_equal %i[mw1 mw2 handler], order
  end

  it 'handles a message and processes result' do
    raw_msg = Object.new
    wrapper = Object.new
    result = Dry::Monads::Success(:ok)
    received = nil
    handler = proc { |w|
      received = w
      result
    }
    processed = nil

    # Create an instance of the class to test instance methods after middleware is added
    @instance = @klass.new

    @instance.stub(:process_result, ->(w, r) { processed = [w, r] }) do
      Rubyists::Leopard::MessageWrapper.stub(:new, wrapper) do
        @instance.send(:handle_message, raw_msg, handler)
      end
    end

    assert_equal wrapper, received
    assert_equal [wrapper, result], processed
  end

  it 'responds with error when handler raises' do
    raw_msg = Object.new
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond_with_error, nil, ['boom'])
    Rubyists::Leopard::MessageWrapper.stub(:new, wrapper) do
      @instance.send(:handle_message, raw_msg, proc { raise 'boom' })
    end
    wrapper.verify
  end

  it 'responds when processing Success result' do
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond, nil, ['ok'])
    result = Rubyists::Leopard::NatsApiServer::Success.new('ok')
    @instance.send(:process_result, wrapper, result)
    wrapper.verify
  end

  it 'responds when processing Failure result' do
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond_with_error, nil, ['fail'])
    result = Rubyists::Leopard::NatsApiServer::Failure.new('fail')
    @instance.send(:process_result, wrapper, result)
    wrapper.verify
  end
end
