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
          # Unpacking the metrics as whole words is cheaper than unpacking both
          # fields separately.
          words = @metric_data.unpack('N*')

          if words.length == @metrics.length
            count = @metrics.length
            i = 0
            while i < count
              @metrics[i] ||= metric_from_word(words[i])
              i += 1
            end
          else
            # Truncated table: fall back to the per-field unpack, which leaves
            # missing fields as nil instead of raising.
            values = @metric_data.unpack('ns>' * @metrics.length)
            @metrics.each_index do |i|
              @metrics[i] ||= HorizontalMetric.new(values[i * 2], values[(i * 2) + 1])
            end
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

      # Build a horizontal metric out of a raw metric word.
      #
      # @param word [Integer]
      # @return [HorizontalMetric]
      def metric_from_word(word)
        left_side_bearing = word & 0xffff
        left_side_bearing -= 0x10000 if left_side_bearing >= 0x8000

        HorizontalMetric.new(word >> 16, left_side_bearing)
      end

      # Metric for the given (long metric) glyph, read straight from the raw
      # table data.
      #
      # @param index [Integer]
      # @return [HorizontalMetric]
      def metric_at(index)
        metric_from_word(@metric_data.unpack1('N', offset: index * 4))
      end

      def build_widths
        count = @metrics.length
        result = Array.new(count + @left_side_bearings.length)
        i = 0

        if @metrics_loaded || @metrics.any?
          # At least one metric has been materialized, so a caller may have
          # adjusted it. Build the widths from the metrics, exactly as before.
          metrics.each do |metric|
            result[i] = metric.advance_width
            i += 1
          end
        else
          # An advance width is the high half of the 4-byte big-endian metric
          # word, so widths can be read straight out of the table data.
          # Going through #metrics would allocate a HorizontalMetric for
          # every glyph in the font (tens of thousands for large fonts) only
          # to copy one integer out of each.
          words = @metric_data.unpack('N*')

          if words.length == count
            while i < count
              result[i] = words[i] >> 16
              i += 1
            end
          else
            # Truncated table: preserve the historical nil-tolerant result.
            metrics.each do |metric|
              result[i] = metric.advance_width
              i += 1
            end
          end
        end

        result.fill(@last_advance_width, count)
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
