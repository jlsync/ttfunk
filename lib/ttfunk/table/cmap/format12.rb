# frozen_string_literal: true

require_relative 'subtable'

module TTFunk
  class Table
    class Cmap
      # Format 12: Segmented coverage.
      #
      # This module conditionally extends {TTFunk::Table::Cmap::Subtable}.
      module Format12
        include SupportedFormat

        # Encode the encoding record to format 12.
        #
        # @param charmap [Hash{Integer => Integer}] a hash mapping character
        #   codes to glyph IDs from the original font.
        # @return [Hash]
        #   * `:charmap` (<tt>Hash{Integer => Hash}</tt>) keys are the characrers in
        #     `charset`, values are hashes:
        #     * `:old` (<tt>Integer</tt>) - glyph ID in the original font.
        #     * `:new` (<tt>Integer</tt>) - glyph ID in the subset font.
        #     that maps the characters in charmap to a
        #   * `:subtable` (<tt>String</tt>) - serialized encoding record.
        #   * `:max_glyph_id` (<tt>Integer</tt>) - maximum glyph ID in the new font.
        def self.encode(charmap)
          next_id = 0
          glyph_map = { 0 => 0 }
          range_firstglyphs = []
          range_firstcodes = []
          range_lengths = []
          last_glyph = last_code = -999

          new_map = {}
          charmap.keys.sort.each do |code|
            old_gid = charmap[code]
            glyph_map[old_gid] ||= next_id += 1
            new_id = glyph_map[old_gid]
            new_map[code] = { old: old_gid, new: new_id }

            if code > last_code + 1 || new_id > last_glyph + 1
              range_firstcodes << code
              range_firstglyphs << new_id
              range_lengths << 1
            else
              range_lengths[-1] += 1
            end
            last_code = code
            last_glyph = new_id
          end

          subtable = [
            12, 0, 16 + (12 * range_lengths.size), 0, range_lengths.size,
          ].pack('nnNNN')
          groups = []
          range_lengths.each_with_index do |len, i|
            firstcode = range_firstcodes[i]
            groups << firstcode << (firstcode + len - 1) << range_firstglyphs[i]
          end
          subtable << groups.pack('N*')

          { charmap: new_map, subtable: subtable, max_glyph_id: next_id + 1 }
        end

        private

        def parse_cmap!
          fractional_version, @language, groupcount = io.read(14).unpack('nx4NN')
          if fractional_version != 0
            raise NotImplementedError,
              "cmap version 12.#{fractional_version} is not supported"
          end
          @code_map = {}
          groups = read(groupcount * 12, 'N*')
          i = 0
          limit = groupcount * 3
          while i < limit
            startchar = groups[i]
            endchar = groups[i + 1]
            glyph_delta = groups[i + 2] - startchar
            code = startchar
            while code <= endchar
              @code_map[code] = code + glyph_delta
              code += 1
            end
            i += 3
          end
        end
      end
    end
  end
end
