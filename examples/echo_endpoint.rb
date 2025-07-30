#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/leopard/nats_api_server'

# Example to echo the given message
class EchoService
  include Rubyists::Leopard::NatsApiServer

  endpoint :echo, &:data
end

if __FILE__ == $PROGRAM_NAME
  EchoService.run(
    nats_url: 'nats://localhost:4222',
    service_opts: { name: 'example.echo', version: '1.0.0' },
    instances: 4,
  )
end
