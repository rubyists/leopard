# frozen_string_literal: true

module Rubyists
  module Leopard
    # Base Leopard exception that truncates backtraces for cleaner logs.
    class LeopardError < StandardError
      # Captures the original exception state while replacing the backtrace with the current call stack.
      #
      # @return [void]
      def initialize(...)
        super
        set_backtrace(caller)
      end

      # Returns a Leopard-truncated backtrace.
      #
      # @return [Array<String>] Up to the first four backtrace entries, plus a truncation marker when applicable.
      def backtrace
        # If the backtrace is nil, return an empty array
        orig = (super || [])[0..3]
        # If the backtrace is less than 4 lines, return it as is
        return orig if orig.size < 4

        # Otherwise, add a note indicating truncation
        orig + ['... (truncated by Leopard)']
      end
    end

    # Generic Leopard error superclass.
    class Error < LeopardError; end
    # Raised when Leopard configuration is invalid.
    class ConfigurationError < Error; end
    # Raised when a handler returns an unsupported object instead of a result monad.
    class ResultError < Error; end
  end
end
