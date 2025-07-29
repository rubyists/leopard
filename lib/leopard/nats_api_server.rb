# frozen_string_literal: true

require 'nats/client'
require 'dry/monads'
require_relative 'message_wrapper'

module Rubyists
  module Leopard
    module NatsApiServer
      include Dry::Monads[:result]

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def endpoints = @endpoints ||= []
        def middleware = @middleware ||= []

        def endpoint(name, subject: nil, queue: nil, &handler)
          endpoints << { name:, subject: subject || name, queue:, handler: }
        end

        def use(klass, *args, &block)
          middleware << [klass, args, block]
        end

        def run(nats_url:, service_opts:, instances: 4)
          spawn_instances(nats_url, service_opts, instances)
        end

        private

        def spawn_instances(url, opts, count)
          Array.new(count) { spawn_ractor(url, opts) }
        end

        def spawn_ractor(url, opts)
          eps = endpoints.dup
          Ractor.new(url, opts, eps) { |u, o, e| setup_worker(u, o, e) }
        end

        def setup_worker(url, opts, eps)
          client  = NATS.connect url
          service = client.services.add(**opts)
          add_endpoints service, eps
          # The main Ractor can just go to sleep
          sleep
        end

        def add_endpoints(service, endpoints)
          endpoints.each do |ep|
            service.endpoints.add(
              ep[:name], subject: ep[:subject], queue: ep[:queue]
            ) do |raw_msg|
              wrapper = MessageWrapper.new(raw_msg)
              dispatch_with_middleware(wrapper, ep[:handler])
            end
          end
        end

        def dispatch_with_middleware(wrapper, handler)
          app = ->(w) { handle_message(w.raw, handler) }
          middleware.reverse_each do |(klass, args, blk)|
            app = klass.new(app, *args, &blk)
          end
          app.call(wrapper)
        end

        def handle_message(raw_msg, handler)
          wrapper = MessageWrapper.new(raw_msg)
          result  = instance_exec(wrapper, &handler)
          process_result(wrapper, result)
        rescue StandardError => e
          wrapper.respond_with_error(e.message)
        end

        def process_result(wrapper, result)
          case result
          in Success
            wrapper.respond(result.value!)
          in Failure
            wrapper.respond_with_error(result.failure)
          end
        end
      end
    end
  end
end
