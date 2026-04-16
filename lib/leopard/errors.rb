# frozen_string_literal: true

module Rubyists
  module Leopard
    class LeopardError < StandardError
      def initialize(...)
        super
        set_backtrace(caller)
      end

      def backtrace
        # If the backtrace is nil, return an empty array
        orig = (super || [])[0..3]
        # If the backtrace is less than 4 lines, return it as is
        return orig if orig.size < 4

        # Otherwise, add a note indicating truncation
        orig + ['... (truncated by Leopard)']
      end
    end

    class Error < LeopardError; end
    class ConfigurationError < Error; end
    class ResultError < Error; end
  end
end
