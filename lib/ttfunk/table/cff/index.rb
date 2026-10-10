# frozen_string_literal: true

module TTFunk
  class Table
    class Cff < TTFunk::Table
      # CFF Index.
      class Index < TTFunk::SubTable
        include Enumerable

        # Get value by index.
        #
        # @param index [Integer]
        # @return [any]
        def [](index)
          return if index >= items_count

          entry_cache[index] ||=
            decode_item(
              index,
              data_reference_offset + offsets[index],
              offsets[index + 1] - offsets[index],
            )
        end

        # Iterate over index items.
        #
        # @overload each()
        #   @yieldparam item [any]
        #   @return [void]
        # @overload each()
        #   @return [Enumerator]
        def each(&block)
          return to_enum(__method__) unless block

          items_count.times do |i|
            yield(self[i])
          end
        end

        # Numer of items in this index.
        #
        # @return [Integer]
        def items_count
          @offsets ? @offsets.length - 1 : 0
        end

        # Encode index.
        #
        # @param args all arguments are passed to `encode_item` method.
        # @return [TTFunk::EncodedString]
        def encode(*args)
          # The default #encode_items returns every raw item verbatim and in
          # order, so the encoded body is just the raw item data. Slicing and
          # re-joining tens of thousands of items is then pure overhead.
          return encode_raw_items if method(:encode_items).owner == TTFunk::Table::Cff::Index

          new_items = encode_items(*args)

          if new_items.empty?
            return [0].pack('n')
          end

          if new_items.length > 0xffff
            raise Error, 'Too many items in a CFF index'
          end

          offsets_array = [1]
          current_offset = 1
          plain_strings = true
          new_items.each do |item|
            plain_strings &&= item.is_a?(String)
            current_offset += item.length
            offsets_array << current_offset
          end

          offset_size = (offsets_array.last.bit_length + 7) / 8

          result = EncodedString.new.concat(
            [new_items.length, offset_size].pack('nC'),
            encode_offsets(offsets_array, offset_size),
          )

          if plain_strings
            # A single append of the joined items is much cheaper than shoveling
            # tens of thousands of small strings one by one.
            result << new_items.join
          else
            new_items.each { |item| result << item }
          end

          result
        end

        private

        attr_reader :offsets
        attr_reader :data_reference_offset

        # Encode an index whose items are the raw data, in order.
        #
        # @return [TTFunk::EncodedString]
        def encode_raw_items
          return [0].pack('n') if items_count.zero?

          if items_count > 0xffff
            raise Error, 'Too many items in a CFF index'
          end

          # Raw offsets start at the first item; encoded offsets start at 1.
          first = offsets[0]
          offset_size = ((offsets[items_count] - first + 1).bit_length + 7) / 8

          EncodedString.new.concat(
            [items_count, offset_size].pack('nC'),
            encode_offsets(offsets, offset_size, 1 - first),
            @data,
          )
        end

        def entry_cache
          @entry_cache ||= {}
        end

        # All raw items. Sliced from the index data on first use.
        def items
          @items ||= Array.new(items_count) { |i| item(i) }
        end

        # Raw item at the given index.
        def item(index)
          return @items[index] if @items

          @data.byteslice(offsets[index] - offsets[0], offsets[index + 1] - offsets[index])
        end

        # Returns an array of EncodedString elements (plain strings,
        # placeholders, or EncodedString instances). Each element is supposed to
        # represent an encoded item.
        #
        # This is the place to do all the filtering, reordering, or individual
        # item encoding.
        #
        # It gets all the arguments `encode` gets.
        def encode_items(*)
          items
        end

        # By default do nothing
        def decode_item(index, _offset, _length)
          item(index)
        end

        # @param offsets [Array<Integer>]
        # @param offset_size [Integer] number of bytes per offset
        # @param shift [Integer] added to every offset before packing
        # @return [String]
        def encode_offsets(offsets, offset_size, shift = 0)
          if offset_size == 3
            # Offsets are packed as a C/n pair, which needs a flat argument
            # array. Building it in place avoids an intermediate shifted array
            # and flat_map's per-item arrays.
            packed = Array.new(offsets.length * 2)
            i = 0
            if shift.zero?
              offsets.each do |offset|
                packed[i] = offset >> 16
                packed[i + 1] = offset & 0xffff
                i += 2
              end
            else
              offsets.each do |offset|
                offset += shift
                packed[i] = offset >> 16
                packed[i + 1] = offset & 0xffff
                i += 2
              end
            end
            packed.pack('Cn' * offsets.length)
          else
            offsets = offsets.map { |offset| offset + shift } if shift.nonzero?

            case offset_size
            when 1
              offsets.pack('C*')
            when 2
              offsets.pack('n*')
            when 4
              offsets.pack('N*')
            end
          end
        end

        def parse!
          @entry_cache = {}

          num_entries = io.read(2).unpack1('n')

          if num_entries.zero?
            @length = 2
            @items = []
            return
          end

          offset_size = io.getbyte

          @offsets = unpack_offsets(io.read((num_entries + 1) * offset_size), offset_size)

          @data_reference_offset = table_offset + 3 + (offsets.length * offset_size) - 1

          @length =
            2 + # num entries
            1 + # offset size
            (offsets.length * offset_size) + # offsets
            offsets.last - 1 # items

          # Items are sliced lazily from this data, see #item.
          @data = io.read(offsets.last - offsets.first)
        end

        def unpack_offsets(offset_data, offset_size)
          case offset_size
          when 1
            offset_data.unpack('C*')
          when 2
            offset_data.unpack('n*')
          when 3
            bytes = offset_data.unpack('C*')
            Array.new(bytes.length / 3) { |i|
              (bytes[i * 3] << 16) | (bytes[(i * 3) + 1] << 8) | bytes[(i * 3) + 2]
            }
          when 4
            offset_data.unpack('N*')
          end
        end
      end
    end
  end
end
