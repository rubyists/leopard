# frozen_string_literal: true

require_relative 'verb'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Collects `$SRV.PING` responses.
        #
        # On success, the result exposes `:responses`.
        class Ping < Verb
          # Invokes {NatsServiceDiscovery#ping}.
          #
          # @param discovery [NatsServiceDiscovery] Discovery helper.
          #
          # @return [Array<Hash>] Parsed ping responses.
          def public_send_verb(discovery, **)
            discovery.ping(**)
          end
        end
      end
    end
  end
end
