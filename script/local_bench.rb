# frozen_string_literal: true

require 'benchmark'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ttfunk'
require 'ttfunk/subset'

# Subset the font to the given code point range and encode it.
def subset_and_encode(original, range)
  subset = TTFunk::Subset::Unicode.new(original)
  range.each { |cp| subset.use(cp) }
  subset.encode
end

# Time repeated subset encoding of a font and print the result.
def bench_encode(label, font_path, iterations: 10, range: (0x20..0xFF))
  original = TTFunk::File.open(font_path)
  GC.start
  GC.disable
  t =
    Benchmark.measure do
      iterations.times do
        subset_and_encode(original, range)
      end
    end
  GC.enable
  puts(
    format(
      '%<label>-35s %<time>8.3fs (iter=%<iters>d, glyphs=%<glyphs>d)',
      label: label, time: t.real, iters: iterations, glyphs: range.size,
    ),
  )
end

iterations = Integer(ENV.fetch('ITERS', '10'), 10)
fonts_dir = File.join(__dir__, '..', 'spec', 'fonts')

bench_encode('TTF encode (DejaVuSans.ttf)', File.join(fonts_dir, 'DejaVuSans.ttf'), iterations: iterations)
bench_encode(
  'OTF encode (ComicJens-Regular.otf)', File.join(fonts_dir, 'ComicJens-Regular.otf'),
  iterations: iterations,
)
