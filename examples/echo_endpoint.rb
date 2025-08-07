#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/leopard/nats_api_server'

# Example to echo the given message
class EchoService
  include Rubyists::Leopard::NatsApiServer

  def initialize(a_var: 1)
    logger.info "EchoService initialized with a_var: #{a_var}"
  end

  endpoint(:echo) { |msg| Success(msg.data) }
  endpoint(:echo_fail) { |msg| Failure({ failure: '*boom*', data: msg.data }) }
end

if __FILE__ == $PROGRAM_NAME
  EchoService.run(
    nats_url: 'nats://localhost:4222',
    service_opts: {
      name: 'example.echo',
      version: '1.0.0',
      instance_args: { a_var: 2 },
    },
    instances: 1,
  )
end
