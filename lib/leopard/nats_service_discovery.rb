# frozen_string_literal: true

require 'json'
require 'nats/client'

module Rubyists
  module Leopard
    # Collects NATS Service API monitoring responses from a cluster.
    #
    # The NATS Service API uses request/reply subjects such as `$SRV.INFO`.
    # Cluster-wide requests can receive multiple replies, so this helper creates
    # an inbox subscription, publishes the request, and collects replies until a
    # short timeout elapses.
    class NatsServiceDiscovery
      # Default NATS Service API monitoring prefix.
      DEFAULT_PREFIX = '$SRV'
      # Default idle timeout used to decide that all service replies arrived.
      DEFAULT_TIMEOUT = 0.25

      attr_reader :client, :prefix

      # @param client [NATS::Client] Connected NATS client.
      # @param prefix [String] Service API monitoring prefix.
      def initialize(client:, prefix: DEFAULT_PREFIX)
        @client = client
        @prefix = prefix
      end

      # Collects `$SRV.PING` responses.
      #
      # @param name [String, nil] Optional service name filter.
      # @param id [String, nil] Optional service id filter; requires `name`.
      # @param timeout [Numeric] Idle timeout while collecting replies.
      #
      # @return [Array<Hash>] Parsed ping responses.
      def ping(name: nil, id: nil, timeout: DEFAULT_TIMEOUT)
        collect_json(service_subject('PING', name:, id:), timeout:)
      end

      # Collects `$SRV.INFO` responses.
      #
      # @param name [String, nil] Optional service name filter.
      # @param id [String, nil] Optional service id filter; requires `name`.
      # @param timeout [Numeric] Idle timeout while collecting replies.
      #
      # @return [Array<Hash>] Parsed info responses.
      def info(name: nil, id: nil, timeout: DEFAULT_TIMEOUT)
        collect_json(service_subject('INFO', name:, id:), timeout:)
      end

      # Collects `$SRV.STATS` responses.
      #
      # @param name [String, nil] Optional service name filter.
      # @param id [String, nil] Optional service id filter; requires `name`.
      # @param timeout [Numeric] Idle timeout while collecting replies.
      #
      # @return [Array<Hash>] Parsed stats responses.
      def stats(name: nil, id: nil, timeout: DEFAULT_TIMEOUT)
        collect_json(service_subject('STATS', name:, id:), timeout:)
      end

      # Builds a subject-to-listener map from service info responses.
      #
      # @param name [String, nil] Optional service name filter.
      # @param id [String, nil] Optional service id filter; requires `name`.
      # @param timeout [Numeric] Idle timeout while collecting replies.
      #
      # @return [Hash{String => Array<Hash>}] Endpoint listeners keyed by subject.
      def endpoint_subject_map(name: nil, id: nil, timeout: DEFAULT_TIMEOUT)
        info(name:, id:, timeout:).each_with_object({}) do |service, subjects|
          Array(service['endpoints']).each do |endpoint|
            subject = endpoint['subject']
            next if subject.to_s.empty?

            subjects[subject] ||= []
            subjects[subject] << listener_entry(service, endpoint)
          end
        end
      end

      # Builds a Service API monitoring subject.
      #
      # @param verb [String, Symbol] Monitoring verb such as `INFO`.
      # @param name [String, nil] Optional service name filter.
      # @param id [String, nil] Optional service id filter; requires `name`.
      #
      # @return [String] Monitoring subject.
      def service_subject(verb, name: nil, id: nil)
        raise ArgumentError, 'service id requires a service name' if present?(id) && !present?(name)

        parts = [prefix, verb.to_s.upcase]
        parts << name.to_s if present?(name)
        parts << id.to_s if present?(id)
        parts.join('.')
      end

      private

      # Collects JSON replies for a Service API subject until `timeout` elapses.
      #
      # @param subject [String] Service API subject to publish.
      # @param timeout [Numeric] Idle timeout while waiting for replies.
      #
      # @return [Array<Hash>] Parsed response payloads.
      def collect_json(subject, timeout:)
        replies = []
        sub = subscribe_to_inbox
        client.publish(subject, '', sub.subject)
        begin
          collect_replies(sub, replies, timeout)
        rescue NATS::Timeout
          replies
        end
      ensure
        sub&.unsubscribe
      end

      # Subscribes to an ephemeral reply inbox and flushes the subscription.
      #
      # @return [NATS::Subscription] Subscription bound to the reply inbox.
      def subscribe_to_inbox
        sub = client.subscribe(client.new_inbox)
        client.flush
        sub
      end

      # Appends parsed replies to the provided accumulator until timeout.
      #
      # @param sub [NATS::Subscription] Reply subscription.
      # @param replies [Array<Hash>] Response accumulator.
      # @param timeout [Numeric] Idle timeout while waiting for replies.
      #
      # @return [void]
      def collect_replies(sub, replies, timeout)
        loop do
          msg = sub.next_msg(timeout:)
          next if no_responders?(msg)

          replies << JSON.parse(msg.data)
        end
      end

      # Reports whether a reply is the server no-responders status message.
      #
      # @param msg [NATS::Msg] Reply message.
      #
      # @return [Boolean]
      def no_responders?(msg)
        msg.header && msg.header['Status'] == '503'
      end

      # Builds a subject-map listener entry from a service and endpoint payload.
      #
      # @param service [Hash] Parsed `$SRV.INFO` service response.
      # @param endpoint [Hash] Endpoint payload from the service response.
      #
      # @return [Hash] Listener entry suitable for subject maps.
      def listener_entry(service, endpoint)
        {
          'service' => service['name'],
          'service_id' => service['id'],
          'version' => service['version'],
          'endpoint' => endpoint['name'],
          'queue_group' => endpoint['queue_group'],
          'metadata' => endpoint['metadata'],
        }
      end

      # Reports whether a value is present for subject construction.
      #
      # @param value [Object] Value to check.
      #
      # @return [Boolean]
      def present?(value)
        !value.nil? && !value.to_s.empty?
      end
    end
  end
end
