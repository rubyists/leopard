# frozen_string_literal: true

require 'helper'
require Rubyists::Leopard.libroot / 'leopard/nats_api_server'

describe 'Rubyists::Leopard::NatsApiServer' do # rubocop:disable Metrics/BlockLength
  before do
    @klass = Class.new do
      include Rubyists::Leopard::NatsApiServer
    end

    mod = Rubyists::Leopard::NatsApiServer
    cm  = mod::ClassMethods
    cm.const_set(:Success, mod::Success) unless cm.const_defined?(:Success)
    cm.const_set(:Failure, mod::Failure) unless cm.const_defined?(:Failure)
  end

  it 'registers an endpoint' do
    blk = proc {}
    @klass.endpoint(:foo, &blk)

    assert_equal [{ name: :foo, subject: :foo, queue: nil, handler: blk }], @klass.endpoints
  end

  it 'registers an endpoint with options' do
    blk = proc {}
    @klass.endpoint(:foo, subject: 'bar', queue: 'q', &blk)

    assert_equal [{ name: :foo, subject: 'bar', queue: 'q', handler: blk }], @klass.endpoints
  end

  it 'adds middleware' do
    blk = proc {}
    @klass.use(String, 1, &blk)

    assert_equal [[String, [1], blk]], @klass.middleware
  end

  it 'delegates run to spawn_instances' do
    args = nil
    @klass.stub(:spawn_instances, ->(url, opts, count) { args = [url, opts, count] }) do
      @klass.run(nats_url: 'nats://', service_opts: { name: 'svc' }, instances: 2)
    end

    assert_equal ['nats://', { name: 'svc' }, 2], args
  end

  it 'dispatches through middleware in reverse order' do
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
    handler = ->(w) { w.log << :handler }
    wrapper = Struct.new(:raw, :log).new(:raw, order)
    @klass.use mw1
    @klass.use mw2
    @klass.stub(:handle_message, ->(_raw, h) { h.call(wrapper) }) do
      @klass.send(:dispatch_with_middleware, wrapper, handler)
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
    @klass.stub(:process_result, ->(w, r) { processed = [w, r] }) do
      Rubyists::Leopard::MessageWrapper.stub(:new, wrapper) do
        @klass.send(:handle_message, raw_msg, handler)
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
      @klass.send(:handle_message, raw_msg, proc { raise 'boom' })
    end
    wrapper.verify
  end

  it 'responds when processing Success result' do
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond, nil, ['ok'])
    result = Rubyists::Leopard::NatsApiServer::Success.new('ok')
    @klass.send(:process_result, wrapper, result)
    wrapper.verify
  end

  it 'responds when processing Failure result' do
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond_with_error, nil, ['fail'])
    result = Rubyists::Leopard::NatsApiServer::Failure.new('fail')
    @klass.send(:process_result, wrapper, result)
    wrapper.verify
  end
end
