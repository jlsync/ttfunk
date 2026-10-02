# frozen_string_literal: true

module TTFunk
  # Bit crunching utility methods.
  module BinUtils
    # Turn a bunch of small integers into one big integer. Assumes big-endian.
    #
    # @param arr [Array<Integer>]
    # @param bit_width [Integer] bit width of the elements
    # @return [Integer]
    def stitch_int(arr, bit_width:)
      value = 0
      shift = 0

      arr.each do |element|
        value |= element << shift
        shift += bit_width
      end

      value
    end
    module_function :stitch_int

    # Slice a big integer into a bunch of small integers. Assumes big-endian.
    #
    # @param value [Integer]
    # @param bit_width [Integer] bit width of the elements
    # @param slice_count [Integer] number of elements to slice into. This is
    #   needed for cases where top bits are zero.
    # @return [Array<Integer>]
    def slice_int(value, bit_width:, slice_count:)
      mask = (1 << bit_width) - 1

      Array.new(slice_count) do |i|
        (value >> (bit_width * i)) & mask
      end
    end
    module_function :slice_int

    # Two's compliment to an integer.
    #
    # @param num [Integer]
    # @param bit_width [Integer] number width
    # @return [Integer]
    def twos_comp_to_int(num, bit_width:)
      sign_bit = 1 << (bit_width - 1)
      (num & sign_bit).nonzero? ? num - (1 << bit_width) : num
    end
    module_function :twos_comp_to_int

    # Turns a (sorted) sequence of values into a series of two-element arrays
    # where the first element is the start and the second is the length.
    #
    # @param values [Array<Integer>]
    # @return [Array<Array(Integer, Integer)>]
    def rangify(values)
      return [] if values.empty?

      ranges = []
      start = values.first
      prev = start

      values.each_with_index do |val, idx|
        next if idx.zero?

        if val - prev > 1
          ranges << [start, prev - start]
          start = val
        end
        prev = val
      end

      ranges << [start, prev - start]
      ranges
    end
    module_function :rangify
  end
end
