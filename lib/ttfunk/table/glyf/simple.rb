# frozen_string_literal: true

require_relative '../../reader'

module TTFunk
  class Table
    class Glyf
      # Simple TrueType glyph
      class Simple
        # Glyph ID.
        # @return [Integer]
        attr_reader :id

        # Binary serialization of this glyph.
        # @return [String]
        attr_reader :raw

        # Number of contours in this glyph.
        # @return [Integer]
        attr_reader :number_of_contours

        # Minimum x for coordinate.
        # @return [Integer]
        attr_reader :x_min

        # Minimum y for coordinate.
        # @return [Integer]
        attr_reader :y_min

        # Maximum x for coordinate.
        # @return [Integer]
        attr_reader :x_max

        # Maximum y for coordinate.
        # @return [Integer]
        attr_reader :y_max

        # Point indices for the last point of each contour.
        # @return [Array<Integer>]
        attr_reader :end_points_of_contours

        # Total number of bytes for instructions.
        # @return [Integer]
        attr_reader :instruction_length

        # Instruction byte code.
        # @return [Array<Integer>]
        attr_reader :instructions

        # @param id [Integer] glyph ID.
        # @param raw [String]
        def initialize(id, raw)
          @id = id
          @raw = raw

          @number_of_contours, @x_min, @y_min, @x_max, @y_max = raw.unpack('s>5')

          endpoints_len = number_of_contours * 2
          @end_points_of_contours = raw.byteslice(10, endpoints_len).unpack('n*')
          offset = 10 + endpoints_len
          @instruction_length = raw.byteslice(offset, 2).unpack1('n')
          @instructions = raw.byteslice(offset + 2, instruction_length).unpack('C*')
        end

        # Is this glyph compound?
        # @return [false]
        def compound?
          false
        end

        # Recode glyph.
        #
        # @param _mapping Unused, here for API compatibility.
        # @return [String]
        def recode(_mapping)
          raw
        end

        # End point index of last contour.
        # @return [Integer]
        def end_point_of_last_contour
          end_points_of_contours.last + 1
        end
      end
    end
  end
end
