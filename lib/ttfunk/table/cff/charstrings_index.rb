# frozen_string_literal: true

module TTFunk
  class Table
    class Cff < TTFunk::Table
      # CFF Charstrings Index.
      class CharstringsIndex < TTFunk::Table::Cff::Index
        # Top dict.
        # @return [TTFunk::Table::Cff::TopDict]
        attr_reader :top_dict

        # @overload initialize(top_dict, file, offset, length = nil)
        #   @param top_dict [TTFunk::Table:Cff::TopDict]
        #   @param file [TTFunk::File]
        #   @param offset [Integer]
        #   @param length [Integer]
        def initialize(top_dict, *remaining_args)
          super(*remaining_args)
          @top_dict = top_dict
        end

        private

        def decode_item(index, _offset, _length)
          TTFunk::Table::Cff::Charstring.new(index, top_dict, font_dict_for(index), super)
        end

        def encode_items(charmap)
          # CharStrings INDEX entries are indexed by glyph ID, so there must be
          # exactly one entry per glyph, starting with the implicit .notdef at
          # GID 0. Codes that share a glyph must not add extra entries, and
          # subsets whose cmap has no entry for code 0 (Unicode, Unicode8Bit)
          # still need .notdef.
          old_glyph_id_for = { 0 => 0 }
          charmap.each_value do |mapping|
            old_glyph_id_for[mapping[:new]] ||= mapping[:old] if mapping[:new].nonzero?
          end

          old_glyph_id_for.keys.sort.map { |glyph_id| item(old_glyph_id_for[glyph_id]) }
        end

        def font_dict_for(index)
          # only CID-keyed fonts contain an FD selector and font dicts
          if top_dict.is_cid_font?
            fd_index = top_dict.font_dict_selector[index]
            top_dict.font_index[fd_index]
          end
        end
      end
    end
  end
end
