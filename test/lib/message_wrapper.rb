# frozen_string_literal: true

require 'helper'
require 'leopard/message_wrapper'

class FakeMsg
  attr_reader :data, :header, :responded_payload, :error_args

  def initialize(data, header = {})
    @data = data
    @header = header
  end

  def respond(payload)
    @responded_payload = payload
  end

  def respond_with_error(err)
    @error_args = [err]
  end
end

describe Rubyists::Leopard::MessageWrapper do # rubocop:disable Metrics/BlockLength
  let(:header) { { 'a' => 'b' } }
  let(:msg)    { FakeMsg.new('{"foo":1}', header) }
  let(:wrapper) { Rubyists::Leopard::MessageWrapper.new(msg) }

  it 'exposes the raw message' do
    assert_equal msg, wrapper.raw
  end

  it 'parses JSON data' do
    assert_equal({ 'foo' => 1 }, wrapper.data)
  end

  it 'provides headers as a hash' do
    assert_equal header, wrapper.headers
  end

  it 'returns raw data on JSON parse failure' do
    bad_msg = FakeMsg.new('not json')
    bad_wrap = Rubyists::Leopard::MessageWrapper.new(bad_msg)

    assert_equal 'not json', bad_wrap.data
  end

  it 'responds with a string payload as-is' do
    wrapper.respond('ok')

    assert_equal 'ok', msg.responded_payload
  end

  it 'serializes non-string payloads to JSON when responding' do
    wrapper.respond(foo: 2)

    assert_equal '{"foo":2}', msg.responded_payload
  end

  it 'responds with error' do
    wrapper.respond_with_error('fail')

    assert_equal ['fail'], msg.error_args
  end

  it 'coerces exception objects to strings when responding with error' do
    err = StandardError.new('broken')
    wrapper.respond_with_error(err)

    assert_equal ['broken'], msg.error_args
  end
end
