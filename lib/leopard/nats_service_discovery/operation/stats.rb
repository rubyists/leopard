# frozen_string_literal: true

require_relative 'verb'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Collects `$SRV.STATS` responses.
        #
        # On success, the result exposes `:responses`.
        class Stats < Verb
          # Invokes {NatsServiceDiscovery#stats}.
          #
          # @param discovery [NatsServiceDiscovery] Discovery helper.
          #
          # @return [Array<Hash>] Parsed stats responses.
          def public_send_verb(discovery, **)
            discovery.stats(**)
          end
        end
      end
    end
  end
end
