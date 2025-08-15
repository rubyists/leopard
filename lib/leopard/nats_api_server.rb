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
          pool = spawn_instances(nats_url, service_opts, instances, workers, blocking)
          logger.info 'Setting up signal trap...'
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
        # @param workers [Array] The array to store worker instances.
        # @param blocking [Boolean] If false, does not block current thread after starting the server.
        #
        # @return [Concurrent::FixedThreadPool] The thread pool managing the worker threads.
        def spawn_instances(url, opts, count, workers, blocking)
          pool = Concurrent::FixedThreadPool.new(count)
          @instance_args = opts.delete(:instance_args) || nil
          logger.info "Building #{count} workers with options: #{opts.inspect}, instance_args: #{@instance_args}"
          raise ArgumentError, 'instance_args must be a Hash' if @instance_args && !@instance_args.is_a?(Hash)

          count.times do
            pool.post { build_worker(url, opts, workers, blocking) }
          end
          pool
        end

        # Builds a worker instance and sets it up with the NATS server.
        #
        # @param nats_url [String] The URL of the NATS server.
        # @param service_opts [Hash] Options for the NATS service.
        # @param workers [Array] The array to store worker instances.
        # @param blocking [Boolean] If true, blocks the current thread until the worker is set up.
        #
        # @return [void]
        def build_worker(nats_url, service_opts, workers, blocking)
          worker = @instance_args ? new(**@instance_args) : new
          workers << worker
          args = { nats_url:, service_opts: }
          return worker.setup_worker!(**args) if blocking

          worker.setup_worker(**args)
        end

        # Shuts down the NATS API server gracefully.
        #
        # @param workers [Array] The array of worker instances to stop.
        # @param pool [Concurrent::FixedThreadPool] The thread pool managing the worker threads.
        #
        # @return [Proc] A lambda that performs the shutdown operations.
        def shutdown(workers, pool)
          lambda do
            logger.warn 'Draining worker subscriptions...'
            workers.each(&:stop)
            logger.warn 'All workers stopped, shutting down pool...'
            pool.shutdown
            logger.warn 'Pool is shut down, waiting for termination!'
            pool.wait_for_termination
            logger.warn 'Bye bye!'
            wake_main_thread_and_exit!
          end
        end

        # Sets up signal traps for graceful shutdown of the NATS API server.
        #
        # @param workers [Array] The array of worker instances to stop on signal.
        # @param pool [Concurrent::FixedThreadPool] The thread pool managing the worker threads.
        #
        # @return [void]
        def trap_signals(workers, pool)
          return if @trapped

          %w[INT TERM QUIT].each do |sig|
            trap(sig) do
              logger.warn "Received #{sig} signal, shutting down..."
              Thread.new { shutdown(workers, pool).call }
            end
          end
          @trapped = true
        end

        # Wakes up the main thread to allow it to continue execution after the server is stopped.
        # This is useful when the server is running in a blocking mode.
        # If the main thread is not blocked, this method does nothing.
        #
        # @return [void]
        def wake_main_thread_and_exit!
          Thread.main.wakeup
          exit 0
        rescue ThreadError
          exit 0
        rescue StandardError
          exit 1
        end
      end

      module InstanceMethods
        # Returns the logger configured for the NATS API server.
        def logger = self.class.logger

        # Sets up a worker thread for the NATS API server.
        # This method connects to the NATS server, adds the service, groups, and endpoints,
        #
        # @param url [String] The URL of the NATS server.
        # @param opts [Hash] Options for the NATS service.
        # @param eps [Array<Hash>] The list of endpoints to add.
        # @param gps [Hash] The groups to add.
        #
        # @return [void]
        def setup_worker(nats_url: 'nats://localhost:4222', service_opts: {})
          @thread  = Thread.current
          @client  = NATS.connect nats_url
          @service = @client.services.add(build_service_opts(service_opts:))
          gps = self.class.groups.dup
          eps = self.class.endpoints.dup
          group_map = add_groups(gps)
          add_endpoints eps, group_map
        end

        # Sets up a worker thread for the NATS API server and blocks the current thread.
        #
        # @see #setup_worker
        def setup_worker!(nats_url: 'nats://localhost:4222', service_opts: {})
          setup_worker(nats_url:, service_opts:)
          sleep
        end

        # Stops the NATS API server worker.
        def stop
          @service&.stop
          @client&.close
          @thread&.wakeup
        rescue ThreadError
          nil
        end

        private

        # Builds the service options for the NATS service.
        #
        # @param service_opts [Hash] Options for the NATS service.
        #
        # @return [Hash] The complete service options including name and version.
        def build_service_opts(service_opts:)
          {
            name: self.class.name.split('::').join('.'),
            version: '0.1.0',
          }.merge(service_opts)
        end

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
