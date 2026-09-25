# frozen_string_literal: true

module TTFunk
  class Table
    class Cff < TTFunk::Table
      # CFF Subroutine index.
      class SubrIndex < TTFunk::Table::Cff::Index
        # Subroutine index biase. For correct subroutine selection the
        # calculated bias must be added to the subroutine number operand before
        # accessing the index.
        # @return [Integer]
        def bias
          if items_count < 1240
            107
          elsif items_count < 33_900
            1131
          else
            32_768
          end
        end
      end
    end
  end
end
