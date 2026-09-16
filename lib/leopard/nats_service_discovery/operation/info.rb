# frozen_string_literal: true

require_relative 'verb'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Collects `$SRV.INFO` responses.
        #
        # On success, the result exposes `:responses`.
        class Info < Verb
          # Invokes {NatsServiceDiscovery#info}.
          #
          # @param discovery [NatsServiceDiscovery] Discovery helper.
          #
          # @return [Array<Hash>] Parsed info responses.
          def public_send_verb(discovery, **)
            discovery.info(**)
          end
        end
      end
    end
  end
end
