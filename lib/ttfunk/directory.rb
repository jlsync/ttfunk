# frozen_string_literal: true

module TTFunk
  # SFNT table directory.
  class Directory
    # Table descriptors
    # @return [Hash{String => Hash}]
    attr_reader :tables

    # Scaler type
    # @return [Integer]
    attr_reader :scaler_type

    def initialize(io, offset = 0)
      io.seek(offset)

      # https://www.microsoft.com/typography/otspec/otff.htm#offsetTable
      # We're ignoring searchRange, entrySelector, and rangeShift here, but
      # skipping past them to get to the table information.
      @scaler_type, table_count = io.read(12).unpack('Nn')

      @tables = {}
      if table_count.positive?
        raw_tables = io.read(table_count * 16)
        if raw_tables
          entries = raw_tables.unpack('a4NNN' * table_count)
          entries.each_slice(4) do |tag, checksum, table_offset, length|
            @tables[tag] = {
              tag: tag,
              checksum: checksum,
              offset: table_offset,
              length: length,
            }
          end
        end
      end
    end
  end
end
