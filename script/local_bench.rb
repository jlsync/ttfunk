# frozen_string_literal: true

require 'benchmark'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ttfunk'
require 'ttfunk/subset'

def subset_and_encode(original, range)
  subset = TTFunk::Subset::Unicode.new(original)
  range.each { |cp| subset.use(cp) }
  subset.encode
end

def bench_encode(label, font_path, iterations: 10, range: (0x20..0xFF))
  original = TTFunk::File.open(font_path)
  GC.start
  GC.disable
  t = Benchmark.measure do
    iterations.times do
      subset_and_encode(original, range)
    end
  end
  GC.enable
  puts format("%-35s %8.3fs (iter=%d, glyphs=%d)", label, t.real, iterations, range.size)
end

iterations = (ENV['ITERS'] || '10').to_i

bench_encode('TTF encode (DejaVuSans.ttf)', File.join(__dir__, '..', 'spec', 'fonts', 'DejaVuSans.ttf'), iterations: iterations)
bench_encode('OTF encode (ComicJens-Regular.otf)', File.join(__dir__, '..', 'spec', 'fonts', 'ComicJens-Regular.otf'), iterations: iterations)
