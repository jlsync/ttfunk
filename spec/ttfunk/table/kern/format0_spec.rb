# frozen_string_literal: true

require 'spec_helper'
require 'ttfunk/table/kern/format0'

describe TTFunk::Table::Kern::Format0 do
  it 'preserves unsigned glyph IDs above 32767 for all pairs' do
    # header: n_pairs=2, search_range=0, entry_selector=0, range_shift=0
    # pair 1: left=40000, right=50000, value=-15
    # pair 2: left=45000, right=60000, value=25
    binary_data = [2, 0, 0, 0, 40_000, 50_000, -15, 45_000, 60_000, 25].pack('n4n2s>n2s>')
    subtable = described_class.new(data: binary_data)

    expect(subtable.pairs).to eq(
      [40_000, 50_000] => -15,
      [45_000, 60_000] => 25,
    )
  end
end
