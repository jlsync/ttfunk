# frozen_string_literal: true

module TTFunk
  # TrueType font collection. Usually a file with `.ttc` extension.
  class Collection
    include Enumerable

    # Load a TrueType collection.
    #
    # @overload open(io)
    #   @param io [IO] IO to read the collection from.
    #   @yieldparam collection [TTFunk::Collection]
    #   @return [any] whatever the block returns
    # @overload open(file_path)
    #   @param file_path [String, Pathname] Path to the font collection file.
    #   @yieldparam collection [TTFunk::Collection]
    #   @return [any] whatever the block returns
    def self.open(path)
      if path.respond_to?(:read)
        result = yield(new(path))
        path.rewind
        result
      else
        ::File.open(path, 'rb') do |io|
          yield(new(io))
        end
      end
    end

    # @param io [IO(#read & #rewind)]
    # @raise [ArgumentError] if `io` doesn't start with a ttc tag
    def initialize(io)
      @contents = io.read
      raise ArgumentError, 'not a TTC file' unless @contents&.start_with?('ttcf')

      count = @contents.byteslice(8, 4).unpack1('N')
      @offsets = @contents.byteslice(12, count * 4).unpack('N*')
      @cache = []
    end

    # Number of fonts in this collection.
    #
    # @return [Integer]
    def count
      @offsets.length
    end

    # Iterate over fonts in the collection.
    #
    # @yieldparam font [TTFunk::File]
    # @return [self]
    def each
      count.times do |index|
        yield(self[index])
      end
      self
    end

    # Get font by index.
    #
    # @param index [Integer]
    # @return [TTFunk::File]
    def [](index)
      @cache[index] ||= TTFunk::File.new(@contents, @offsets[index])
    end
  end
end
