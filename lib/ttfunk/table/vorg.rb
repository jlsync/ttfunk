# frozen_string_literal: true

require_relative '../table'

module TTFunk
  class Table
    # Vertical Origin (`VORG`) table.
    class Vorg < Table
      # Table tag.
      TAG = 'VORG'

      # Table major version.
      # @return [Integer]
      attr_reader :major_version

      # Table minor version.
      # @return [Integer]
      attr_reader :minor_version

      # The default y coordinate of a glyph’s vertical origin.
      # @return [Integer]
      attr_reader :default_vert_origin_y

      # Number of vertical origin metrics.
      # @return [Integer]
      attr_reader :count

      # Encode table.
      #
      # @return [String]
      def self.encode(vorg)
        return unless vorg

        ''.b.tap do |table|
          table << [
            vorg.major_version, vorg.minor_version,
            vorg.default_vert_origin_y, vorg.count,
          ].pack('n*')

          origins_data = []
          vorg.origins.each_pair do |glyph_id, vert_origin_y|
            origins_data << glyph_id << vert_origin_y
          end
          table << origins_data.pack('n*')
        end
      end

      # Get vertical origina for glyph by ID.
      #
      # @param glyph_id [Integer]
      # @return [Integer]
      def for(glyph_id)
        @origins.fetch(glyph_id, default_vert_origin_y)
      end

      # Table tag.
      #
      # @return [String]
      def tag
        TAG
      end

      # Origins map.
      #
      # @return [Hash{Integer => Integer}]
      def origins
        @origins ||= {}
      end

      private

      def parse!
        @major_version, @minor_version, @default_vert_origin_y, @count =
          read(8, 'n2s>n')

        if @count.positive?
          origin_data = read(@count * 4, 'ns>' * @count)
          origin_data.each_slice(2) do |glyph_id, vert_origin_y|
            origins[glyph_id] = vert_origin_y
          end
        end
      end
    end
  end
end
