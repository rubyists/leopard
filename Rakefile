# frozen_string_literal: true

require 'rake'
require 'minitest/test_task'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'net/http'
require 'shellwords'
require 'timeout'

RuboCop::RakeTask.new

Minitest::TestTask.create(:test) do |task|
  task.libs << 'lib'
  task.libs << 'test'
  task.test_globs = ['test/*/**/*.rb']
  task.warning = true
end

QUICK_TEST_FILES = Dir['test/*/**/*.rb'].reject { |file| file.start_with?('test/integration/') }.sort.freeze

def nats_health_uri = URI('http://127.0.0.1:8222/healthz')

def nats_ready?
  Net::HTTP.get_response(nats_health_uri).is_a?(Net::HTTPSuccess)
rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET
  false
end

def wait_for_nats!
  Timeout.timeout(30) do
    sleep 1 until nats_ready?
  end
rescue Timeout::Error
  raise 'Timed out waiting for NATS JetStream health endpoint on http://127.0.0.1:8222/healthz'
end

def container_runtime
  File.executable?('/usr/bin/podman') || system('command -v podman > /dev/null 2>&1', exception: false) ? 'podman' : 'docker'
end

def run_quick_tests!
  sh "ruby -w -Ilib -Itest #{QUICK_TEST_FILES.shelljoin}"
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
    sh("#{container_runtime} rm -f #{ENV.fetch('NATS_NAME', 'leopard-nats')}", verbose: false)
  rescue RuntimeError
    nil
  end
end

namespace :ci do
  desc 'Run RuboCop and the non-integration test suite without managing NATS'
  task quick: :rubocop do
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
task ci: %w[rubocop ci:test]

task default: :ci
