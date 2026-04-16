# frozen_string_literal: true

require 'socket'
require 'erb'

module Rubyists
  module Leopard
    module MetricsServer
      private

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

      def handle_metrics_client(client, workers)
        request_line = client.gets
        loop { break if (client.gets || '').chomp.empty? }
        write_metrics_response(client, request_line, workers)
      rescue StandardError => e
        logger.warn "Metrics request error: #{e.message}"
      ensure
        close_client(client)
      end

      def close_client(client)
        client.close
      rescue StandardError
        nil
      end

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

      def prometheus_metrics(workers)
        metrics = collect_prometheus_metrics(workers)
        render_metrics_template(metrics)
      end

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

      def render_metrics_template(metrics)
        ERB.new(File.read(metrics_template_path), trim_mode: '-').result_with_hash(metrics)
      end

      def metrics_template_path
        File.expand_path('templates/prometheus_metrics.erb', __dir__)
      end
    end
  end
end
