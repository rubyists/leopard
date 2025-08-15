#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/leopard/nats_api_server'

# Example to echo the given message
class ServiceGroups
  include Rubyists::Leopard::NatsApiServer

  def initialize(a_var: 1)
    logger.info "ServiceGroups initialized with a_var: #{a_var}"
  end

  group :mammal
  group :feline, group: :mammal, queue: :meow
  endpoint(:sound, group: :feline) { |msg| Success("Meow! #{msg.data}") }
  endpoint(:fail, group: :feline) { |msg| Failure({ reason: 'cat nap', data: msg.data }) }
end

if __FILE__ == $PROGRAM_NAME
  SemanticLogger.default_level = :info
  SemanticLogger.add_appender(io: $stdout, formatter: :color)
  ServiceGroups.run(
    nats_url: 'nats://localhost:4222',
    service_opts: {
      name: 'example.groups',
      version: '1.0.0',
      instance_args: { a_var: 2 },
    },
    instances: 1,
  )
end
