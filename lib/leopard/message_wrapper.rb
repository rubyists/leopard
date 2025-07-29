# frozen_string_literal: true

require 'json'

module Rubyists
  module Leopard
    class MessageWrapper
      attr_reader :raw, :data, :headers

      def initialize(nats_msg)
        @raw     = nats_msg
        @data    = parse_data(nats_msg.data)
        @headers = nats_msg.header.to_h
      end

      def respond(payload)
        raw.respond(serialize(payload))
      end

      def respond_with_error(err, code: 500)
        raw.respond_with_error(err.to_s, code:)
      end

      private

      def parse_data(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        raw
      end

      def serialize(obj)
        obj.is_a?(String) ? obj : JSON.generate(obj)
      end
    end
  end
end
