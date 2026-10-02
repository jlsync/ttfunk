# frozen_string_literal: true

require_relative 'format10'
require 'stringio'

module TTFunk
  class Table
    class Post
      # Version 2.0 is used for fonts that use glyph names that are not in the
      # set of Macintosh glyph names. A given font may map some of its glyphs to
      # the standard Macintosh glyph names, and some to its own custom names.
      # A version 2.0 `post` table can be used in fonts with TrueType or CFF
      # version 2 outlines.
      module Format20
        include Format10

        # Get glyph name for character code.
        #
        # @param code [Integer]
        # @return [String]
        def glyph_for(code)
          index = @glyph_name_index[code]
          return '.notdef' unless index

          if index <= 257
            POSTSCRIPT_GLYPHS[index]
          else
            @names[index - 258] || '.notdef'
          end
        end

        private

        def parse_format!
          number_of_glyphs = io.read(2).unpack1('n')
          @glyph_name_index = read(number_of_glyphs * 2, 'n*')
          @names = []

          raw_strings = io.read(offset + length - io.pos)
          return unless raw_strings

          pos = 0
          total_len = raw_strings.bytesize
          while pos < total_len
            str_len = raw_strings.getbyte(pos)
            pos += 1
            @names << raw_strings.byteslice(pos, str_len)
            pos += str_len
          end
        end
      end
    end
  end
end
