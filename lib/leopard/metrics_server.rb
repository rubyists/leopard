# frozen_string_literal: true

require 'socket'
require 'erb'

module Rubyists
  module Leopard
    # Adds a minimal Prometheus HTTP endpoint for Leopard worker metrics.
    module MetricsServer
      private

      # Starts a lightweight HTTP server that exposes Leopard Prometheus metrics.
      #
      # @param workers [Array<Object>] Active Leopard worker instances to observe.
      #
      # @return [Thread] The server thread.
      def start_metrics_server(workers)
        port = ENV.fetch('LEOPARD_METRICS_PORT', '9394').to_i
        Thread.new do
          server = TCPServer.new(port)
          logger.info "Metrics server listening on :#{port}"
          loop { Thread.new(server.accept) { |client| handle_metrics_client(client, workers) } }
        rescue StandardError => e
          logger.error "Metrics server error: #{e.message}"
        end
      end

      # Handles an individual metrics HTTP client connection.
      #
      # @param client [TCPSocket] The connected HTTP client.
      # @param workers [Array<Object>] Active Leopard worker instances to observe.
      #
      # @return [void]
      def handle_metrics_client(client, workers)
        request_line = client.gets
        loop { break if (client.gets || '').chomp.empty? }
        write_metrics_response(client, request_line, workers)
      rescue StandardError => e
        logger.warn "Metrics request error: #{e.message}"
      ensure
        close_client(client)
      end

      # Closes a metrics client socket, ignoring cleanup failures.
      #
      # @param client [TCPSocket] The connected HTTP client.
      #
      # @return [void]
      def close_client(client)
        client.close
      rescue StandardError
        nil
      end

      # Writes the HTTP response for a metrics request.
      #
      # @param client [TCPSocket] The connected HTTP client.
      # @param request_line [String, nil] The first line of the HTTP request.
      # @param workers [Array<Object>] Active Leopard worker instances to observe.
      #
      # @return [void]
      def write_metrics_response(client, request_line, workers)
        if request_line&.start_with?('GET /metrics')
          body = prometheus_metrics(workers)
          client.write "HTTP/1.1 200 OK\r\n" \
                       "Content-Type: text/plain; version=0.0.4\r\n" \
                       "Content-Length: #{body.bytesize}\r\n\r\n#{body}"
        else
          client.write "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        end
      end

      # Builds the Prometheus metrics payload for the current worker state.
      #
      # @param workers [Array<Object>] Active Leopard worker instances to observe.
      #
      # @return [String] Rendered Prometheus text exposition output.
      def prometheus_metrics(workers)
        metrics = collect_prometheus_metrics(workers)
        render_metrics_template(metrics)
      end

      # Aggregates per-subject worker utilization metrics.
      #
      # @param workers [Array<Object>] Active Leopard worker instances to observe.
      #
      # @return [Hash{Symbol => Object}] Metric hashes for the Prometheus template.
      def collect_prometheus_metrics(workers)
        busy    = Hash.new(0)
        pending = Hash.new(0)
        workers.each { |w| accumulate_worker_metrics(w, busy, pending) }
        {
          busy:,
          pending:,
          subjects: (busy.keys | pending.keys).sort,
          total: workers.size,
        }
      end

      # Adds one worker's endpoint saturation metrics to the aggregate hashes.
      #
      # @param worker [Object] A Leopard worker instance.
      # @param busy [Hash{String => Integer}] Subject-to-busy-worker counts.
      # @param pending [Hash{String => Integer}] Subject-to-pending-message counts.
      #
      # @return [void]
      def accumulate_worker_metrics(worker, busy, pending)
        service = worker.instance_variable_get(:@service)
        return unless service

        service.endpoints.each do |ep|
          # TODO: use ep.handler once nats-pure.rb adds attr_reader :handler to NATS::Service::Endpoint
          sub = ep.instance_variable_get(:@handler)
          next unless sub

          subj = ep.subject.to_s
          busy[subj]    += sub.concurrency_semaphore.available_permits.zero? ? 1 : 0
          pending[subj] += sub.pending_queue&.size.to_i
        end
      end

      # Renders the metrics ERB template with aggregated metric data.
      #
      # @param metrics [Hash{Symbol => Object}] Aggregated metric data for template rendering.
      #
      # @return [String] The rendered Prometheus payload.
      def render_metrics_template(metrics)
        ERB.new(File.read(metrics_template_path), trim_mode: '-').result_with_hash(metrics)
      end

      # Returns the absolute path to the Prometheus metrics template.
      #
      # @return [String] The metrics template path.
      def metrics_template_path
        File.expand_path('templates/prometheus_metrics.erb', __dir__)
      end
    end
  end
end
