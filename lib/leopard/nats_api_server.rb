# frozen_string_literal: true

require 'nats/client'
require 'dry/monads'
require 'concurrent'
require_relative '../leopard'
require_relative 'message_wrapper'

module Rubyists
  module Leopard
    module NatsApiServer
      include Dry::Monads[:result]
      extend Dry::Monads[:result]

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def endpoints = @endpoints ||= []
        def groups = @groups ||= {}
        def middleware = @middleware ||= []

        def endpoint(name, subject: nil, queue: nil, group: nil, &handler)
          endpoints << {
            name:,
            subject: subject || name,
            queue:,
            group:,
            handler:,
          }
        end

        def group(name, group: nil, queue: nil)
          groups[name] = { name:, parent: group, queue: }
        end

        def use(klass, *args, &block)
          middleware << [klass, args, block]
        end

        def run(nats_url:, service_opts:, instances: 4)
          spawn_instances(nats_url, service_opts, instances)
          sleep
        end

        private

        def spawn_instances(url, opts, count)
          pool = Concurrent::FixedThreadPool.new(count)
          count.times do
            eps = endpoints.dup
            gps = groups.dup
            pool.post { setup_worker(url, opts, eps, gps) }
          end
          pool
        end

        def setup_worker(url, opts, eps, gps)
          client  = NATS.connect url
          service = client.services.add(**opts)
          group_map = add_groups(service, gps)
          add_endpoints service, eps, group_map
          # Keep the worker thread alive
          sleep
        end

        def add_groups(service, gps)
          created = {}
          gps.each_key { |name| build_group(service, gps, created, name) }
          created
        end

        def build_group(service, defs, cache, name)
          return cache[name] if cache.key?(name)

          gdef = defs[name]
          raise ArgumentError, "Group #{name} not defined" unless gdef

          parent = gdef[:parent] ? build_group(service, defs, cache, gdef[:parent]) : service
          cache[name] = parent.groups.add(gdef[:name], queue: gdef[:queue])
        end

        def add_endpoints(service, endpoints, group_map)
          endpoints.each do |ep|
            parent = ep[:group] ? group_map[ep[:group]] : service
            raise ArgumentError, "Group #{ep[:group]} not defined" if ep[:group] && parent.nil?

            parent.endpoints.add(
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
          logger.error 'Error processing message: ', e
          wrapper.respond_with_error(e.message)
        end

        def process_result(wrapper, result)
          case result
          in Dry::Monads::Success
            wrapper.respond(result.value!)
          in Dry::Monads::Failure
            logger.error 'Error processing message: ', result.failure
            wrapper.respond_with_error(result.failure)
          end
        end
      end
    end
  end
end
