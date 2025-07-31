# frozen_string_literal: true

module Rubyists
  module Leopard
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ResultError < Error; end
  end
end
