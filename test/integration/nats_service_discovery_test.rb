# frozen_string_literal: true

require 'securerandom'
require 'open3'
require 'rbconfig'
require 'timeout'
require_relative '../helper'
require Rubyists::Leopard.libroot / 'leopard/nats_service_discovery/operation'

class NatsServiceDiscoveryIntegrationTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  NATS_URL = ENV.fetch('LEOPARD_NATS_URL', ENV.fetch('NATS_URI', 'nats://127.0.0.1:4222'))
  WAIT_TIMEOUT = 5

  def setup # rubocop:disable Metrics/MethodLength
    skip 'NATS broker not available' unless nats_available?

    @token = SecureRandom.hex(4)
    @client = NATS.connect(NATS_URL, reconnect: false, connect_timeout: 0.5, max_reconnect_attempts: 0)
    @service = @client.services.add(
      name: service_name,
      version: '1.2.3',
      description: 'Discovery integration service',
      metadata: { 'schema_registry' => 'proto-schema-registry' },
    )
    add_test_endpoints
    @client.flush
  end

  def teardown
    @service&.stop
    @client&.close
  end

  def test_info_operation_returns_service_endpoint_contracts # rubocop:disable Metrics/AbcSize, Minitest/MultipleAssertions
    result = info_operation

    assert_predicate result, :success?
    assert_equal 1, result[:responses].size
    assert_equal service_name, info_response['name']
    assert_equal ['proto.sum.Request'], endpoint('sum')['metadata']['request']['message']
    assert_equal [avg_subject, sum_subject], endpoint_subjects
  end

  def test_subject_map_operation_groups_listeners_by_subject
    result = operation(:SubjectMap)

    assert_predicate result, :success?
    sum_endpoints = result[:subject_map][sum_subject].map { |listener| listener['endpoint'] }

    assert_equal %w[sum], sum_endpoints
    response_messages = result[:subject_map][avg_subject].map do |listener|
      listener['metadata']['response']['message']
    end

    assert_equal ['proto.avg.Response'], response_messages
  end

  def test_services_operation_summarizes_info
    result = operation(:Services)

    assert_predicate result, :success?
    assert_equal [
      {
        'name' => service_name,
        'id' => @service.id,
        'version' => '1.2.3',
        'endpoints' => 2,
      },
    ], result[:services]
  end

  def test_ping_and_stats_operations_collect_live_service_responses # rubocop:disable Minitest/MultipleAssertions
    @client.request(sum_subject, '{}')

    ping = operation(:Ping)
    stats = operation(:Stats)

    assert_predicate ping, :success?
    assert_predicate stats, :success?
    assert_equal 'io.nats.micro.v1.ping_response', ping[:responses].first['type']
    assert_equal 1, stats_endpoint('sum')['num_requests']
  end

  def test_collect_operation_can_query_a_specific_service_subject
    subject = "$SRV.INFO.#{service_name}"
    result = Rubyists::Leopard::NatsServiceDiscovery::Operation::Collect.call(
      client: @client,
      subject:,
      timeout: 0.5,
    )

    assert_predicate result, :success?
    assert_equal service_name, result[:responses].first['name']
  end

  def test_connect_operation_opens_a_client
    result = Rubyists::Leopard::NatsServiceDiscovery::Operation::Connect.call(
      server: NATS_URL,
      connect_options: { reconnect: false, connect_timeout: 0.5, max_reconnect_attempts: 0 },
    )

    assert_predicate result, :success?
    assert_predicate result[:client], :connected?
  ensure
    result&.[](:client)&.close
  end

  def test_missing_service_returns_empty_responses
    result = Rubyists::Leopard::NatsServiceDiscovery::Operation::Info.call(
      client: @client,
      name: "Missing#{@token}",
      timeout: 0.05,
    )

    assert_predicate result, :success?
    assert_empty result[:responses]
  end

  def test_command_line_tools_query_and_format_service_data # rubocop:disable Metrics/AbcSize, Minitest/MultipleAssertions
    info = command_json('leopard-service-info')
    services = command_json('leopard-services', '--json')
    stats = command_json('leopard-service-stats', '--json')
    subject_map = command_json('leopard-service-map', '--json')

    assert_equal service_name, info.first['name']
    assert_equal service_name, services.first['name']
    assert_equal service_name, stats.first['name']
    assert_includes subject_map, sum_subject
  end

  private

  def nats_available?
    nc = NATS.connect(NATS_URL, reconnect: false, connect_timeout: 0.5, max_reconnect_attempts: 0)
    nc.close
    true
  rescue StandardError
    false
  end

  def command_json(executable, *)
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "exe/#{executable}", '--server', NATS_URL, '--name', service_name, *
    )

    assert_predicate status, :success?, stderr
    JSON.parse(stdout)
  end

  def add_test_endpoints
    @service.endpoints.add('sum', subject: sum_subject, metadata: sum_metadata) do |message|
      message.respond('{"sum":0}')
    end
    @service.endpoints.add('avg', subject: avg_subject, metadata: avg_metadata) do |message|
      message.respond('{"avg":0}')
    end
  end

  def operation(name)
    Rubyists::Leopard::NatsServiceDiscovery::Operation.const_get(name).call(
      client: @client,
      name: service_name,
      timeout: 0.5,
    )
  end

  def info_operation
    @info_operation ||= operation(:Info)
  end

  def info_response
    info_operation[:responses].first
  end

  def endpoint(name)
    info_response['endpoints'].find { |endpoint| endpoint['name'] == name }
  end

  def endpoint_subjects
    info_response['endpoints'].map { |endpoint| endpoint['subject'] }.sort
  end

  def stats_endpoint(name)
    operation(:Stats)[:responses].first['endpoints'].find { |endpoint| endpoint['name'] == name }
  end

  def service_name
    "DiscoveryService#{@token}"
  end

  def sum_subject
    "leopard.discovery.#{@token}.sum"
  end

  def avg_subject
    "leopard.discovery.#{@token}.avg"
  end

  def sum_metadata
    { 'request' => { 'message' => ['proto.sum.Request'] } }
  end

  def avg_metadata
    { 'response' => { 'message' => 'proto.avg.Response' } }
  end
end
