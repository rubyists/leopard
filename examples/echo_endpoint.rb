#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/leopard/nats_api_server'

# Example to echo the given message
class EchoService
  include Rubyists::Leopard::NatsApiServer

  config.logger = SemanticLogger[:EchoService]
  def initialize(a_var: 1)
    logger.info "EchoService initialized with a_var: #{a_var}"
  end

  endpoint(:echo) do |msg|
    data = msg.data
    logger.trace('Received message', data:)
    Success(data)
  end
  endpoint(:echo_fail) do |msg|
    data = msg.data
    logger.trace('Received message', data:)
    Failure({ failure: '*boom*', data: msg.data })
  end
end

if __FILE__ == $PROGRAM_NAME
  SemanticLogger.default_level = :info
  SemanticLogger.add_signal_handler
  SemanticLogger.add_appender(io: $stdout, formatter: :color)
  EchoService.run(
    nats_url: 'nats://localhost:4222',
    service_opts: {
      name: 'example.echo',
      version: '1.0.0',
      instance_args: { a_var: 2 },
    },
    instances: ENV.fetch('ECHO_INSTANCES', '1').to_i,
  )
end
