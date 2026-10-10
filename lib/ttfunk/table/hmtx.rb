# frozen_string_literal: true

require_relative '../table'

module TTFunk
  class Table
    # Horizontal Metrics (`hmtx`) table.
    class Hmtx < Table
      # Glyph horizontal metrics.
      #
      # Metrics are materialized lazily: only glyphs that are actually asked
      # for get a HorizontalMetric instance. Fonts with tens of thousands of
      # glyphs no longer pay for all of them when just a subset is used.
      #
      # @return [Array<HorizontalMetric>]
      def metrics
        return unless @metrics

        unless @metrics_loaded
          values = @metric_data.unpack('ns>' * @metrics.length)
          @metrics.each_index do |i|
            @metrics[i] ||= HorizontalMetric.new(values[i * 2], values[(i * 2) + 1])
          end
          @metrics_loaded = true
        end

        @metrics
      end

      # Left side bearings.
      # @return [Array<Ingteger>]
      attr_reader :left_side_bearings

      # Glyph widths.
      # @return [Array<Integer>]
      def widths
        return unless @metrics

        @widths ||= build_widths
      end

      # Encode table.
      #
      # @param hmtx [TTFunk::Table::Hmtx]
      # @param mapping [Hash{Integer => Integer}] keys are new glyph IDs, values
      #   are old glyph IDs
      # @return [Hash{:number_of_metrics => Integer, :table => String}]
      #   * `:number_of_metrics` - number of mertrics is the table.
      #   * `:table` - encoded table.
      def self.encode(hmtx, mapping)
        sorted_ids = mapping.keys.sort
        metrics_data = []
        sorted_ids.each do |new_id|
          metric = hmtx.for(mapping[new_id])
          metrics_data << metric.advance_width << metric.left_side_bearing
        end

        {
          number_of_metrics: sorted_ids.length,
          table: metrics_data.pack('n*'),
        }
      end

      # Horyzontal glyph metric.
      #
      # @!attribute [rw] advance_width
      #   @return [Integer] Advance width.
      # @!attribute [rw] left_side_bearing
      #   @return [Integer] Left side bearing.
      HorizontalMetric = Struct.new(:advance_width, :left_side_bearing)

      # Get horizontal metric for glyph.
      #
      # @param glyph_id [Integer]
      # @return [HorizontalMetric]
      def for(glyph_id)
        metric = @metrics[glyph_id]
        return metric if metric

        # Negative IDs are out of spec but used to be tolerated through
        # Array#[], so keep resolving them the same way.
        index = glyph_id.negative? ? glyph_id + @metrics.length : glyph_id

        if index >= 0 && index < @metrics.length
          @metrics[index] ||= metric_at(index)
        else
          metrics_cache[glyph_id] ||=
            HorizontalMetric.new(
              @last_advance_width,
              @left_side_bearings[glyph_id - @metrics.length],
            )
        end
      end

      private

      def metrics_cache
        @metrics_cache ||= {}
      end

      # Metric for the given (long metric) glyph, read straight from the raw
      # table data.
      #
      # @param index [Integer]
      # @return [HorizontalMetric]
      def metric_at(index)
        value = @metric_data.unpack1('N', offset: index * 4)
        left_side_bearing = value & 0xffff
        left_side_bearing -= 0x10000 if left_side_bearing >= 0x8000

        HorizontalMetric.new(value >> 16, left_side_bearing)
      end

      def build_widths
        result = Array.new(@metrics.length + @left_side_bearings.length)
        i = 0
        metrics.each do |metric|
          result[i] = metric.advance_width
          i += 1
        end
        result.fill(@last_advance_width, @metrics.length)
        result
      end

      def parse!
        number_of_metrics = file.horizontal_header.number_of_metrics
        @metric_data = io.read(number_of_metrics * 4)
        @metrics = Array.new(number_of_metrics)
        @metrics_loaded = false

        if number_of_metrics.positive?
          @last_advance_width = @metric_data.unpack1('n', offset: (number_of_metrics - 1) * 4)
        end

        lsb_count = file.maximum_profile.num_glyphs - number_of_metrics
        @left_side_bearings = read_signed(lsb_count)
      end
    end
  end
end
