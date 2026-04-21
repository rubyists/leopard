# frozen_string_literal: true

module Rubyists
  module Leopard
    # Configuration for a Leopard JetStream pull-consumer endpoint.
    NatsJetstreamEndpoint = Struct.new(
      :name,
      :stream,
      :subject,
      :durable,
      :consumer,
      :batch,
      :fetch_timeout,
      :nak_delay,
      :handler,
      keyword_init: true,
    )
  end
end
