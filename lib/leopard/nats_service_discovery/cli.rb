# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'operation'

module Rubyists
  module Leopard
    class NatsServiceDiscovery
      # Shared command-line helpers for NATS service discovery executables.
      #
      # @api private
      module CLI
        module_function

        # Parses common NATS discovery CLI options.
        #
        # @param argv [Array<String>] Command-line arguments.
        # @param banner [String] OptionParser banner.
        # @param description [String] Command description.
        # @param json [Boolean] Whether the command supports `--json`.
        #
        # @return [Hash] Parsed options.
        def parse(argv, banner:, description:, json: false)
          opts = default_options(json:)
          OptionParser.new do |parser|
            parser.banner = banner
            parser.separator ''
            parser.separator description
            parser.separator ''
            add_common_options(parser, opts)
          end.parse!(argv)
          validate!(opts)
          opts
        end

        # Opens a NATS client for the duration of the provided block.
        #
        # @param opts [Hash] Parsed CLI options.
        # @yieldparam client [NATS::Client] Connected NATS client.
        #
        # @return [Object] The block return value.
        def with_client(opts)
          result = Operation::Connect.call(
            server: opts[:server],
            creds: opts[:creds],
            connect_options: { reconnect: false, connect_timeout: opts[:timeout] },
          )
          abort_with(result[:error]) unless result.success?

          yield result[:client]
        ensure
          result&.[](:client)&.close
        end

        # Prints a value as pretty JSON.
        #
        # @param value [Object] JSON-serializable value.
        #
        # @return [void]
        def print_json(value)
          puts JSON.pretty_generate(value)
        end

        # Prints rows as a simple aligned table.
        #
        # @param headers [Array<String>] Column headers.
        # @param rows [Array<Array>] Table rows.
        #
        # @return [void]
        def print_table(headers, rows)
          widths = column_widths(headers, rows)
          format = widths.map { |width| "%-#{width}s" }.join('  ')
          puts format % headers
          puts widths.map { |width| '-' * width }.join('  ')
          rows.each { |row| puts format % row }
        end

        # Prints an error and exits with a non-zero status.
        #
        # @param error [Exception] Error to report.
        #
        # @return [void]
        def abort_with(error)
          warn "error: #{error.message}"
          exit 1
        end

        # Returns a successful operation result or aborts the process.
        #
        # @param result [Trailblazer::Operation::Railway::Result] Operation result.
        #
        # @return [Trailblazer::Operation::Railway::Result]
        def operation_result!(result)
          abort_with(result[:error]) unless result.success?

          result
        end

        # Builds discovery operation options from CLI options and a client.
        #
        # @param opts [Hash] Parsed CLI options.
        # @param client [NATS::Client] Connected NATS client.
        #
        # @return [Hash] Arguments for discovery operations.
        def discovery_options(opts, client)
          {
            client:,
            name: opts[:name],
            id: opts[:id],
            prefix: opts[:prefix],
            timeout: opts[:timeout],
          }
        end

        # Builds default CLI options.
        #
        # @param json [Boolean] Whether the command supports `--json`.
        #
        # @return [Hash] Default options.
        def default_options(json:)
          {
            server: ENV.fetch('NATS_URL', 'nats://127.0.0.1:4222'),
            timeout: DEFAULT_TIMEOUT,
            prefix: DEFAULT_PREFIX,
            json: json ? false : nil,
          }
        end

        # Adds all common options to an OptionParser.
        #
        # @param parser [OptionParser] Parser to configure.
        # @param opts [Hash] Mutable parsed option accumulator.
        #
        # @return [void]
        def add_common_options(parser, opts)
          add_connection_options(parser, opts)
          add_filter_options(parser, opts)
          add_output_options(parser, opts)
        end

        # Adds NATS connection options to an OptionParser.
        #
        # @param parser [OptionParser] Parser to configure.
        # @param opts [Hash] Mutable parsed option accumulator.
        #
        # @return [void]
        def add_connection_options(parser, opts)
          parser.on('-s', '--server URL', 'NATS server URL. Defaults to ENV[NATS_URL] or local NATS') do |url|
            opts[:server] = url
          end
          parser.on('--creds FILE', 'NATS user credentials file') { |file| opts[:creds] = file }
        end

        # Adds service filter options to an OptionParser.
        #
        # @param parser [OptionParser] Parser to configure.
        # @param opts [Hash] Mutable parsed option accumulator.
        #
        # @return [void]
        def add_filter_options(parser, opts)
          parser.on('--name NAME', 'Only query services with this name') { |name| opts[:name] = name }
          parser.on('--id ID', 'Only query this service id. Requires --name') { |id| opts[:id] = id }
          parser.on('--prefix PREFIX', 'Service API prefix. Defaults to $SRV') { |prefix| opts[:prefix] = prefix }
          parser.on('-t', '--timeout SECONDS', Float, 'Reply collection idle timeout') { |timeout| opts[:timeout] = timeout }
        end

        # Adds output and help options to an OptionParser.
        #
        # @param parser [OptionParser] Parser to configure.
        # @param opts [Hash] Mutable parsed option accumulator.
        #
        # @return [void]
        def add_output_options(parser, opts)
          parser.on('--json', 'Print JSON output') { opts[:json] = true } unless opts[:json].nil?
          parser.on('-h', '--help', 'Show this help') do
            puts parser
            exit
          end
        end

        # Validates parsed CLI options.
        #
        # @param opts [Hash] Parsed CLI options.
        #
        # @return [void]
        def validate!(opts)
          return unless opts[:id] && opts[:name].to_s.empty?

          warn 'error: --id requires --name'
          exit 1
        end

        # Computes table column widths.
        #
        # @param headers [Array<String>] Column headers.
        # @param rows [Array<Array>] Table rows.
        #
        # @return [Array<Integer>] Width for each column.
        def column_widths(headers, rows)
          headers.each_index.map do |index|
            ([headers[index]] + rows.map { |row| row[index].to_s }).map(&:length).max
          end
        end
      end
    end
  end
end
