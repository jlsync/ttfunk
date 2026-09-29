# frozen_string_literal: true

require 'spec_helper'
require 'ttfunk/subset_collection'

describe TTFunk::SubsetCollection do
  subject(:collection) { described_class.new(font) }

  let(:font) { TTFunk::File.open(test_font('DejaVuSans')) }

  it 'encodes an empty array without creating chunks' do
    expect(collection.encode([])).to eq([])
  end

  it 'encodes MacRoman characters, including zero, as binary bytes' do
    chunks = collection.encode("A\0Äé".codepoints.freeze)

    expect(chunks).to eq([[0, "A\0\x80\x8e".b]])
    expect(chunks.first.last.encoding).to eq(Encoding::BINARY)
  end

  it 'registers repeated characters only once across calls' do
    allow(collection[0]).to receive(:use).and_call_original

    2.times { collection.encode('AAA'.codepoints) }

    expect(collection[0]).to have_received(:use).with(65).once
  end

  it 'keeps spaces in the current subset when switching encodings' do
    chunks = collection.encode('AĀ ЖB'.codepoints)

    expect(chunks).to eq([[0, 'A'.b], [1, '! "'.b], [0, 'B'.b]])
    expect(collection[1].to_unicode_map).to eq(32 => 32, 33 => 0x100, 34 => 0x416)
  end

  it 'starts each call in MacRoman and preserves earlier Unicode assignments' do
    collection.encode('ĀЖ'.codepoints)

    expect(collection.encode(' Ж Ā'.codepoints)).to eq([[0, ' '.b], [1, '" !'.b]])
  end

  it 'retains assignments made through the public use method' do
    collection.use('ЖĀ'.codepoints)

    expect(collection.encode('ĀЖ'.codepoints)).to eq([[1, '"!'.b]])
  end

  it 'opens another subset after all 223 Unicode byte slots are used' do
    characters = (0x400...0x4e0).to_a

    expect(collection.encode(characters)).to eq(
      [[1, (33..255).to_a.pack('C*')], [2, '!'.b]],
    )
    expect(collection[3]).to be_nil
  end

  it 'finds characters in full subsets without registering them again' do
    collection.encode((0x400...0x4e0).to_a)
    subsets = (0..2).map { |index| collection[index] }
    subsets.each { |subset| allow(subset).to receive(:use).and_call_original }

    expect(collection.encode([0x4df, 32, 0x400, 32, 0x4de])).to eq(
      [[2, '! '.b], [1, "! \xff".b]],
    )
    subsets.each { |subset| expect(subset).to_not have_received(:use) }
  end

  it 'supports non-BMP codepoints and retains their Unicode mappings' do
    expect(collection.encode([0x1f600, 32, 0x1f642])).to eq([[1, '! "'.b]])
    expect(collection[1].to_unicode_map).to eq(32 => 32, 33 => 0x1f600, 34 => 0x1f642)
  end
end
