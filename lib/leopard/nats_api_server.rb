# frozen_string_literal: true

require 'nats/client'
require 'dry/monads'
require 'dry/configurable'
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
        base.include(InstanceMethods)
        base.extend(Dry::Monads[:result])
        base.extend(Dry::Configurable)
        base.setting :logger, default: Rubyists::Leopard.logger, reader: true
      end

      Endpoint = Struct.new(:name, :subject, :queue, :group, :handler)

      module ClassMethods
        def endpoints = @endpoints ||= []
        def groups = @groups ||= {}
        def middleware = @middleware ||= []

        # Define an endpoint for the NATS API server.
        #
        # @param name [String] The name of the endpoint.
        # @param subject [String, nil] The NATS subject to listen on. Defaults to the endpoint name.
        # @param queue [String, nil] The NATS queue group to use. Defaults to nil.
        # @param group [String, nil] The group this endpoint belongs to. Defaults to nil.
        # @param handler [Proc] The block that will handle incoming messages.
        #
        # @return [void]
        def endpoint(name, subject: nil, queue: nil, group: nil, &handler)
          endpoints << Endpoint.new(name:, subject: subject || name, queue:, group:, handler:)
        end

        # Define a group for organizing endpoints.
        #
        # @param name [String] The name of the group.
        # @param group [String, nil] The parent group this group belongs to. Defaults to nil.
        # @param queue [String, nil] The NATS queue group to use for this group. Defaults to nil.
        #
        # @return [void]
        def group(name, group: nil, queue: nil)
          groups[name] = { name:, parent: group, queue: }
        end

        # Use a middleware class for processing messages.
        #
        # @param klass [Class] The middleware class to use.
        # @param args [Array] Optional arguments to pass to the middleware class.
        # @param block [Proc] Optional block to pass to the middleware class.
        #
        # @return [void]
        def use(klass, *args, &block)
          middleware << [klass, args, block]
        end

        # Start the NATS API server.
        # This method connects to the NATS server and spawns multiple instances of the API server.
        #
        # @param nats_url [String] The URL of the NATS server to connect to.
        # @param service_opts [Hash] Options for the NATS service.
        # @param instances [Integer] The number of instances to spawn. Defaults to 1.
        # @param blocking [Boolean] If false, does not block current thread after starting the server. Defaults to true.
        #
        # @return [void]
        def run(nats_url:, service_opts:, instances: 1, blocking: true)
          logger.info 'Booting NATS API server...'
          workers = Concurrent::Array.new
          pool = spawn_instances(nats_url, service_opts, instances, workers)
          trap_signals(workers, pool)
          return pool unless blocking

          sleep
        end

        private

        # Spawns multiple instances of the NATS API server.
        #
        # @param url [String] The URL of the NATS server.
        # @param opts [Hash] Options for the NATS service.
        # @param count [Integer] The number of instances to spawn.
        #
        # @return [Concurrent::FixedThreadPool] The thread pool managing the worker threads.
        def spawn_instances(url, opts, count, workers)
          pool = Concurrent::FixedThreadPool.new(count)
          count.times do
            eps = endpoints.dup
            gps = groups.dup
            pool.post { build_worker(url, opts, eps, gps, workers) }
          end
          pool
        end

        def build_worker(url, opts, eps, gps, workers)
          worker = new
          workers << worker
          worker.setup_worker(url, opts, eps, gps)
        end

        def shutdown(workers, pool)
          lambda do
            logger.warn 'Draining worker subscriptions...'
            workers.each(&:stop)
            logger.warn 'All workers stopped, shutting down pool...'
            pool.shutdown
            logger.warn 'Pool is shut down, waiting for termination!'
            pool.wait_for_termination
            logger.warn 'Bye bye!'
            wake_main_thread
          end
        end

        def trap_signals(workers, pool)
          %w[INT TERM QUIT].each do |sig|
            trap(sig) do
              logger.warn "Received #{sig} signal, shutting down..."
              Thread.new { shutdown(workers, pool).call }
            end
          end
        end

        def wake_main_thread
          Thread.main.wakeup
        rescue ThreadError
          nil
        end
      end

      module InstanceMethods
        def logger = self.class.config.logger

        # Sets up a worker thread for the NATS API server.
        # This method connects to the NATS server, adds the service, groups, and endpoints,
        # and keeps the worker thread alive.
        #
        # @param url [String] The URL of the NATS server.
        # @param opts [Hash] Options for the NATS service.
        # @param eps [Array<Hash>] The list of endpoints to add.
        # @param gps [Hash] The groups to add.
        #
        # @return [void]
        def setup_worker(url, opts, eps, gps)
          @thread  = Thread.current
          @client  = NATS.connect url
          @service = @client.services.add(**opts)
          group_map = add_groups(gps)
          add_endpoints eps, group_map
          sleep
        end

        def stop
          @service&.stop
          @client&.close
          @thread&.wakeup
        rescue ThreadError
          nil
        end

        private

        # Adds groups to the NATS service.
        #
        # @param gps [Hash] The groups to add, where keys are group names and values are group definitions.
        #
        # @return [Hash] A map of group names to their created group objects.
        def add_groups(gps)
          created = {}
          gps.each_key { |name| build_group(gps, created, name) }
          created
        end

        # Builds a group in the NATS service.
        #
        # @param defs [Hash] The group definitions, where keys are group names and values are group definitions.
        # @param cache [Hash] A cache to store already created groups.
        # @param name [String] The name of the group to build.
        #
        # @return [NATS::Group] The created group object.
        def build_group(defs, cache, name)
          return cache[name] if cache.key?(name)

          gdef = defs[name]
          raise ArgumentError, "Group #{name} not defined" unless gdef

          parent = gdef[:parent] ? build_group(defs, cache, gdef[:parent]) : @service
          cache[name] = parent.groups.add(gdef[:name], queue: gdef[:queue])
        end

        # Adds endpoints to the NATS service.
        #
        # @param endpoints [Array<Hash>] The list of endpoints to add.
        # @param group_map [Hash] A map of group names to their created group objects.
        #
        # @return [void]
        def add_endpoints(endpoints, group_map)
          endpoints.each do |ep|
            grp = ep.group
            parent = grp ? group_map[grp] : @service
            raise ArgumentError, "Group #{grp} not defined" if grp && parent.nil?

            build_endpoint(parent, ep)
          end
        end

        # Builds an endpoint in the NATS service.
        #
        # @param parent [NATS::Group] The parent group or service to add the endpoint to.
        # @param ept    [Endpoint]    The endpoint definition containing name, subject, queue, and handler.
        #               NOTE: Named ept because `endpoint` is a DSL method we expose, to avoid confusion.
        #
        # @return [void]
        def build_endpoint(parent, ept)
          parent.endpoints.add(ept.name, subject: ept.subject, queue: ept.queue) do |raw_msg|
            wrapper = MessageWrapper.new(raw_msg)
            dispatch_with_middleware(wrapper, ept.handler)
          end
        end

        # Dispatches a message through the middleware stack and handles it with the provided handler.
        #
        # @param wrapper [MessageWrapper] The message wrapper containing the raw message.
        # @param handler [Proc] The handler to process the message.
        #
        # @return [void]
        def dispatch_with_middleware(wrapper, handler)
          app = ->(w) { handle_message(w.raw, handler) }
          self.class.middleware.reverse_each do |(klass, args, blk)|
            app = klass.new(app, *args, &blk)
          end
          app.call(wrapper)
        end

        # Handles a raw NATS message using the provided handler.
        #
        # @param raw_msg [NATS::Message] The raw NATS message to handle.
        # @param handler [Proc] The handler to process the message.
        #
        # @return [void]
        def handle_message(raw_msg, handler)
          wrapper = MessageWrapper.new(raw_msg)
          result  = instance_exec(wrapper, &handler)
          process_result(wrapper, result)
        rescue StandardError => e
          logger.error 'Error processing message: ', e
          wrapper.respond_with_error(e.message)
        end

        # Processes the result of the handler execution.
        #
        # @param wrapper [MessageWrapper] The message wrapper containing the raw message.
        # @param result [Dry::Monads::Result] The result of the handler execution.
        #
        # @return [void]
        # @raise [ResultError] If the result is not a Success or Failure monad.
        def process_result(wrapper, result)
          case result
          in Dry::Monads::Success
            wrapper.respond(result.value!)
          in Dry::Monads::Failure
            logger.error 'Error processing message: ', result.failure
            wrapper.respond_with_error(result.failure)
          else
            logger.error('Unexpected result: ', result:)
            raise ResultError, "Unexpected Response from Handler, must respond with a Success or Failure monad: #{result}"
          end
        end
      end
    end
  end
end
