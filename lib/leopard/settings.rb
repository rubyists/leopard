# frozen_string_literal: true
require 'semantic_logger'

module Rubyists
  module Leopard
    extend Dry::Configurable

    setting :libroot, reader: true, default: Pathname(__FILE__).dirname.join('..').expand_path
    setting :root, reader: true, default: libroot.join('..').expand_path
    setting :logger, reader: true, default: SemanticLogger[:Leopard]
  end
end
