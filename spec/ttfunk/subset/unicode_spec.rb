# frozen_string_literal: true

require 'spec_helper'
require 'ttfunk/subset'

describe TTFunk::Subset::Unicode do
  subject(:subset) { described_class.new(font) }

  let(:font) { TTFunk::File.open(test_font('DejaVuSans')) }

  it 'returns an isolated copy of to_unicode_map' do
    subset.use(0x20)
    subset.use(0x41)

    map1 = subset.to_unicode_map
    map1.delete(0x20)

    expect(subset.to_unicode_map).to include(0x20 => 0x20)
  end

  it 'invalidates glyph mappings and glyphs cache when adding a character after encoding' do
    subset.use(0x41)
    subset.encode
    initial_glyph_count = subset.glyphs.size

    subset.use(0x42)
    expect(subset.glyphs.size).to be > initial_glyph_count
  end
end
