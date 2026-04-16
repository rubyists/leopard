# frozen_string_literal: true

require_relative '../helper'
require Rubyists::Leopard.libroot / 'leopard/nats_request_reply_callbacks'
require 'dry/monads'

class NatsRequestReplyCallbacksTest < Minitest::Test
  def setup
    @logger = Minitest::Mock.new
    @callbacks = Rubyists::Leopard::NatsRequestReplyCallbacks.new(logger: @logger).callbacks
  end

  def test_success_responds_with_value
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond, nil, ['ok'])

    @callbacks[:on_success].call(wrapper, Dry::Monads::Result::Success.new('ok'))

    wrapper.verify
  end

  def test_failure_logs_and_responds_with_error
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond_with_error, nil, ['fail'])
    @logger.expect(:error, nil, ['Error processing message: ', 'fail'])

    @callbacks[:on_failure].call(wrapper, Dry::Monads::Result::Failure.new('fail'))

    wrapper.verify
    @logger.verify
  end

  def test_error_responds_with_error
    error = RuntimeError.new('boom')
    wrapper = Minitest::Mock.new
    wrapper.expect(:respond_with_error, nil, [error])

    @callbacks[:on_error].call(wrapper, error)

    wrapper.verify
  end
end
