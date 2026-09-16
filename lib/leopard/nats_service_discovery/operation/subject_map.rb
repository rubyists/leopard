# frozen_string_literal: true

require 'trailblazer/operation'
require_relative 'discovery_options'
require_relative 'info'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      module Operation
        # Builds a subject-to-endpoint listener map from `$SRV.INFO` responses.
        #
        # On success, the result exposes `:responses` and `:subject_map`.
        class SubjectMap < Trailblazer::Operation
          include DiscoveryOptions

          step :load_info?
          step :map_subjects

          # Loads raw service info responses for mapping.
          #
          # @param ctx [Hash] Operation context.
          #
          # @return [Boolean] Whether service info was loaded.
          def load_info?(ctx, **)
            result = Info.call(**operation_options(ctx))
            ctx[:error] = result[:error] unless result.success?
            ctx[:responses] = result[:responses]
            result.success?
          end

          # Builds a subject-to-listeners map from info responses.
          #
          # @param ctx [Hash] Operation context.
          # @param responses [Array<Hash>] Parsed `$SRV.INFO` responses.
          #
          # @return [Hash] Listener entries keyed by NATS subject.
          def map_subjects(ctx, responses:, **)
            ctx[:subject_map] = responses.each_with_object({}) do |service, subjects|
              Array(service['endpoints']).each do |endpoint|
                add_listener(subjects, service, endpoint)
              end
            end
          end

          private

          # Adds an endpoint listener to the subject map.
          #
          # @param subjects [Hash] Subject map accumulator.
          # @param service [Hash] Parsed `$SRV.INFO` service response.
          # @param endpoint [Hash] Endpoint payload from the service response.
          #
          # @return [void]
          def add_listener(subjects, service, endpoint)
            subject = endpoint['subject']
            return if subject.to_s.empty?

            subjects[subject] ||= []
            subjects[subject] << listener_entry(service, endpoint)
          end

          # Builds a subject-map listener entry.
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
        end
      end
    end
  end
end
