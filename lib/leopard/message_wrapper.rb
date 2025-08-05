# frozen_string_literal: true

require 'json'

module Rubyists
  module Leopard
    class MessageWrapper
      # @!attribute [r] raw
      # @return [NATS::Message] The original NATS message.
      #
      # @!attribute [r] data
      # @return [Object] The parsed data from the NATS message.
      #
      # @!attribute [r] headers
      # @return [Hash] The headers from the NATS message.
      attr_reader :raw, :data, :headers

      # @param nats_msg [NATS::Message] The NATS message to wrap.
      def initialize(nats_msg)
        @raw     = nats_msg
        @data    = parse_data(nats_msg.data)
        @headers = nats_msg.header.to_h
      end

      # @param payload [Object] The payload to respond with.
      #
      # @return [void]
      def respond(payload)
        raw.respond(serialize(payload))
      end

      # @param err [String, Exception] The error message or exception to respond with.
      #
      # @return [void]
      def respond_with_error(err)
        raw.respond_with_error(err.to_s)
      end

      private

      # Parses the raw data from the NATS message.
      # Assumes the data is in JSON format.
      # If parsing fails, it returns the raw string.
      #
      # @param raw [String] The raw data from the NATS message.
      #
      # @return [Object] The parsed data, or the raw string if parsing fails.
      def parse_data(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        raw
      end

      # Serializes the object to a JSON string if it is not already a string.
      # @param obj [Object] The object to serialize.
      #
      # @return [String] The serialized JSON string or the original string.
      def serialize(obj)
        obj.is_a?(String) ? obj : JSON.generate(obj)
      end
    end
  end
end
