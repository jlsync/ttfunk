# frozen_string_literal: true

require 'spec_helper'
require 'ttfunk/subset'

describe TTFunk::Subset::CodePage do
  subject(:subset) { described_class.new(font, 10_000, Encoding::MACROMAN) }

  let(:font) { TTFunk::File.open(test_font('DejaVuSans')) }

  it 'returns byte zero on repeated conversions' do
    2.times { expect(subset.from_unicode(0)).to eq(0) }
  end

  it 'does not retry conversions for unsupported characters' do
    errors = 0
    trace =
      TracePoint.new(:raise) do |event|
        if event.raised_exception.is_a?(Encoding::UndefinedConversionError)
          errors += 1
        end
      end

    trace.enable do
      expect(subset.from_unicode(0x141)).to be_nil
      expect(subset.covers?(0x141)).to be(false)
      expect(subset.includes?(0x141)).to be_nil
    end

    expect(errors).to eq(1)
  end

  it 'keeps conversion misses local to the encoding' do
    other = described_class.new(font, 1252, Encoding::Windows_1252)

    expect(subset.from_unicode(0x178)).to eq(0xd9)
    expect(other.from_unicode(0x178)).to eq(0x9f)
    expect(subset.from_unicode(0xde)).to be_nil
    expect(other.from_unicode(0xde)).to eq(0xde)
  end

  it 'propagates errors for invalid codepoints instead of caching a miss' do
    2.times do
      expect { subset.from_unicode(-1) }.to raise_error(RangeError)
    end
  end

  it 'registers characters after their conversion has been cached' do
    expect(subset.covers?(0xe9)).to be(true)
    expect(subset.includes?(0xe9)).to be_nil

    subset.use(0xe9)

    expect(subset.includes?(0xe9)).to eq(0xe9)
    expect(subset.to_unicode_map).to include(0x8e => 0xe9)
  end

  it 'returns an isolated copy of to_unicode_map' do
    subset.use(0xe9)
    map1 = subset.to_unicode_map
    map1.delete(0x8e)

    expect(subset.to_unicode_map).to include(0x8e => 0xe9)
  end
end
