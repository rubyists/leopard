# frozen_string_literal: true

require 'helper'
require 'leopard/errors'

describe 'Rubyists::Leopard::Errors' do
  def level1
    level2
  end

  def level2
    level3
  end

  def level3
    raise Rubyists::Leopard::Error, 'Error boom'
  end

  it 'truncates backtrace to 5 items' do
    err = assert_raises(Rubyists::Leopard::Error) { level1 }

    bt = err.backtrace

    assert_equal 5, bt.count
    assert_equal '... (truncated by Leopard)', bt.last
    refute(bt.any? { |line| line.include?("in 'level1'") })
  end
end
