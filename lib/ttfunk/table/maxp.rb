# frozen_string_literal: true

require_relative '../table'

module TTFunk
  class Table
    # Maximum Profile (`maxp`) table
    class Maxp < Table
      # Default maximum levels of recursion.
      DEFAULT_MAX_COMPONENT_DEPTH = 1

      # Size of full table version 1.
      MAX_V1_TABLE_LENGTH = 32

      # Table version.
      # @return [Integer]
      attr_reader :version

      # The number of glyphs in the font.
      # @return [Integer]
      attr_reader :num_glyphs

      # Maximum points in a non-composite glyph.
      # @return [Integer]
      attr_reader :max_points

      # Maximum contours in a non-composite glyph.
      # @return [Integer]
      attr_reader :max_contours

      # Maximum points in a composite glyph.
      # @return [Integer]
      attr_reader :max_component_points

      # Maximum contours in a composite glyph.
      # @return [Integer]
      attr_reader :max_component_contours

      # Maximum zones.
      # * 1 if instructions do not use the twilight zone (Z0)
      # * 2 if instructions do use Z0
      # @return [Integer]
      attr_reader :max_zones

      # Maximum points used in Z0.
      # @return [Integer]
      attr_reader :max_twilight_points

      # Number of Storage Area locations.
      # @return [Integer]
      attr_reader :max_storage

      # Number of FDEFs.
      # @return [Integer]
      attr_reader :max_function_defs

      # Number of IDEFs.
      # @return [Integer]
      attr_reader :max_instruction_defs

      # Maximum stack depth across Font Program, CVT Program and all glyph
      # instructions.
      # @return [Integer]
      attr_reader :max_stack_elements

      # Maximum byte count for glyph instructions.
      # @return [Integer]
      attr_reader :max_size_of_instructions

      # Maximum number of components referenced at "top level" for any composite
      # glyph.
      # @return [Integer]
      attr_reader :max_component_elements

      # Maximum levels of recursion.
      # @return [Integer]
      attr_reader :max_component_depth

      class << self
        # Encode table.
        #
        # @param maxp [TTFunk::Table::Maxp]
        # @param new2old_glyph [Hash{Integer => Integer}] keys are new glyph IDs, values
        #   are old glyph IDs.
        # @return [String]
        def encode(maxp, new2old_glyph)
          ''.b.tap do |table|
            num_glyphs = new2old_glyph.length
            table << [maxp.version, num_glyphs].pack('Nn')

            if maxp.version == 0x10000
              stats = stats_for(maxp, new2old_glyph.values)

              table << [
                stats[:max_points],
                stats[:max_contours],
                stats[:max_component_points],
                stats[:max_component_contours],
                # these all come from the fpgm and cvt tables, which
                # we don't support at the moment
                maxp.max_zones,
                maxp.max_twilight_points,
                maxp.max_storage,
                maxp.max_function_defs,
                maxp.max_instruction_defs,
                maxp.max_stack_elements,
                stats[:max_size_of_instructions],
                stats[:max_component_elements],
                stats[:max_component_depth],
              ].pack('n*')
            end
          end
        end

        private

        # Maximum profile statistics for the given glyphs.
        #
        # @param maxp [TTFunk::Table::Maxp]
        # @param glyph_ids [Array<Integer>] glyph IDs in the original font.
        # @return [Hash{Symbol => Integer}]
        def stats_for(maxp, glyph_ids)
          stats = {
            max_points: 0,
            max_contours: 0,
            max_component_points: 0,
            max_component_contours: 0,
            max_component_elements: 0,
            max_component_depth: 0,
            max_size_of_instructions: 0,
          }

          glyph_ids.each do |glyph_id|
            glyph = maxp.file.glyph_outlines.for(glyph_id)
            next unless glyph

            if glyph.compound?
              component_elements = glyph.glyph_ids.size
              stats[:max_component_elements] = component_elements if component_elements > stats[:max_component_elements]

              points, contours, depth = compound_totals(maxp, glyph, 1)

              stats[:max_component_points] = points if points > stats[:max_component_points]
              stats[:max_component_contours] = contours if contours > stats[:max_component_contours]
              stats[:max_component_depth] = depth if depth > stats[:max_component_depth]
            else
              points = glyph.end_point_of_last_contour
              stats[:max_points] = points if points > stats[:max_points]

              contours = glyph.number_of_contours
              stats[:max_contours] = contours if contours > stats[:max_contours]

              instructions = glyph.instruction_length
              if instructions > stats[:max_size_of_instructions]
                stats[:max_size_of_instructions] = instructions
              end
            end
          end

          stats
        end

        # Totals for a composite glyph, aggregated over every component
        # recursively.
        #
        # @param maxp [TTFunk::Table::Maxp]
        # @param glyph [TTFunk::Table::Glyf::Compound]
        # @param depth [Integer] nesting depth of this glyph's components. The
        #   components of a composite glyph are at least one level deep, and a
        #   nested composite adds another level.
        # @return [Array(Integer, Integer, Integer)] total points, total
        #   contours and maximum nesting depth.
        def compound_totals(maxp, glyph, depth)
          total_points = 0
          total_contours = 0
          max_depth = depth

          glyph.glyph_ids.each do |component_id|
            component = maxp.file.glyph_outlines.for(component_id)
            next unless component

            if component.compound?
              points, contours, component_depth = compound_totals(maxp, component, depth + 1)

              total_points += points
              total_contours += contours
              max_depth = component_depth if component_depth > max_depth
            else
              total_points += component.end_point_of_last_contour
              total_contours += component.number_of_contours
            end
          end

          [total_points, total_contours, max_depth]
        end
      end

      private

      def parse!
        @version, @num_glyphs = read(6, 'Nn')

        if @version == 0x10000
          if length == MAX_V1_TABLE_LENGTH
            @max_points, @max_contours, @max_component_points,
              @max_component_contours, @max_zones, @max_twilight_points,
              @max_storage, @max_function_defs, @max_instruction_defs,
              @max_stack_elements, @max_size_of_instructions,
              @max_component_elements, @max_component_depth = read(26, 'n13')
          else
            @max_points, @max_contours, @max_component_points,
              @max_component_contours, @max_zones, @max_twilight_points,
              @max_storage, @max_function_defs, @max_instruction_defs,
              @max_stack_elements, @max_size_of_instructions,
              @max_component_elements = read(24, 'n*')

            # a number of fonts omit these last two bytes for some reason,
            # so we have to supply a default here to prevent nils
            @max_component_depth = DEFAULT_MAX_COMPONENT_DEPTH
          end
        end
      end
    end
  end
end
