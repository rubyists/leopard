# frozen_string_literal: true

require 'helper'

describe 'Rubyists::Leopard' do
  it 'sets libroot' do
    assert_equal Pathname(__FILE__).dirname.join('../../lib'), Rubyists::Leopard.libroot
  end

  it 'sets root' do
    assert_equal Pathname(__FILE__).dirname.join('../..'), Rubyists::Leopard.root
  end
end
