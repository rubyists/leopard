# frozen_string_literal: true

module Rubyists
  module Leopard
    class LeopardError < StandardError
      def backtrace
        super[0..3] + ['... (truncated by Leopard)']
      end
    end

    class Error < LeopardError; end
    class ConfigurationError < Error; end
    class ResultError < Error; end
  end
end
