# frozen_string_literal: true

require 'rake'
require 'minitest/test_task'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'net/http'
require 'open3'
require 'shellwords'
require 'timeout'
require 'yard'
require 'yard/rake/yardoc_task'

RuboCop::RakeTask.new
YARD::Rake::YardocTask.new(:yard)

Minitest::TestTask.create(:test) do |task|
  task.libs << 'lib'
  task.libs << 'test'
  task.test_globs = ['test/*/**/*.rb']
  task.warning = true
end

QUICK_TEST_FILES = Dir['test/*/**/*.rb'].reject { |file| file.start_with?('test/integration/') }.sort.freeze

# Returns the local NATS JetStream health endpoint used by the CI helpers.
#
#
# @return [URI::HTTP] The health endpoint URI.
def nats_health_uri = URI('http://127.0.0.1:8222/healthz')

# Reports whether the local NATS JetStream health endpoint is currently reachable.
#
#
# @return [Boolean] `true` when the broker responds successfully, otherwise `false`.
def nats_ready?
  Net::HTTP.get_response(nats_health_uri).is_a?(Net::HTTPSuccess)
rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET
  false
end

# Waits for the local NATS JetStream broker to report healthy.
#
#
# @return [void]
# @raise [RuntimeError] If the broker does not become healthy within 30 seconds.
def wait_for_nats!
  Timeout.timeout(30) do
    sleep 1 until nats_ready?
  end
rescue Timeout::Error
  raise 'Timed out waiting for NATS JetStream health endpoint on http://127.0.0.1:8222/healthz'
end

# Detects the container runtime used to manage the local NATS broker.
#
#
# @return [String] `podman` when available, otherwise `docker`.
def container_runtime
  File.executable?('/usr/bin/podman') || system('command -v podman > /dev/null 2>&1', exception: false) ? 'podman' : 'docker'
end

# Runs the non-integration test files directly for a fast local feedback loop.
#
#
# @return [void]
def run_quick_tests!
  sh "ruby -w -Ilib -Itest #{QUICK_TEST_FILES.shelljoin}"
end

# Verifies that the current YARD coverage is complete.
#
#
# @return [void]
# @raise [RuntimeError] If YARD reports anything less than 100% documentation coverage.
def verify_yard_coverage!
  output, status = Open3.capture2e('bundle', 'exec', 'yard', 'stats', '--list-undoc')
  puts output
  raise 'yard stats failed' unless status.success?
  return if output.include?('100.00% documented')

  raise 'YARD documentation coverage is incomplete'
end

namespace :nats do
  desc 'Start the local NATS JetStream broker via ./ci/nats/start.sh'
  task :start do
    sh({ 'NATS_DETACH' => '1' }, './ci/nats/start.sh')
  end

  desc 'Wait for the local NATS JetStream broker health endpoint'
  task :wait do
    wait_for_nats!
  end

  desc 'Stop the local NATS JetStream broker container'
  task :stop do
    name = ENV.fetch('NATS_NAME', 'leopard-nats')
    sh(container_runtime, 'rm', '-f', name, verbose: false)
  rescue RuntimeError
    nil
  end
end

namespace :ci do
  desc 'Run RuboCop, YARD verification, and the non-integration test suite without managing NATS'
  task quick: %i[rubocop yard:verify] do
    run_quick_tests!
  end

  desc 'Run the full test suite against a managed local NATS JetStream broker'
  task :test do
    Rake::Task['nats:start'].invoke
    Rake::Task['nats:wait'].invoke
    Rake::Task['test'].invoke
  ensure
    Rake::Task['nats:stop'].reenable
    Rake::Task['nats:stop'].invoke
  end
end

desc 'Run RuboCop and the full test suite against a managed local NATS JetStream broker'
task ci: %w[rubocop yard:verify ci:test]

namespace :yard do
  desc 'Fail if YARD reports incomplete documentation coverage'
  task :verify do
    verify_yard_coverage!
  end
end

task default: :ci
