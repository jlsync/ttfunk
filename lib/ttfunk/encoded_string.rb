# frozen_string_literal: true

require 'stringio'
require_relative 'placeholder'

module TTFunk
  # Risen when the final encoded string was requested but there were some
  # unresolved placeholders in it.
  class UnresolvedPlaceholderError < StandardError
  end

  # Risen when a placeholder is added to an Encoded String but it already
  # contains a placeholder with the same name.
  class DuplicatePlaceholderError < StandardError
  end

  # Encoded string takes care of placeholders in binary strings. Placeholders
  # are used when bytes need to be placed in the stream before their value is
  # known.
  #
  # @api private
  class EncodedString
    # @yieldparam [self]
    def initialize
      @string = +''.b
      yield(self) if block_given?
    end

    # Append to string.
    #
    # @param obj [String, Placeholder, EncodedString]
    # @return [self]
    def <<(obj)
      case obj
      when String
        @string << obj
      when Placeholder
        add_placeholder(obj)
        @string << ("\0" * obj.length)
      when self.class
        # adjust placeholders to be relative to the entire encoded string
        obj.placeholders.each_pair do |_, placeholder|
          add_placeholder(placeholder.dup, placeholder.position + @string.bytesize)
        end

        @string << obj.unresolved_string
      end

      self
    end

    # Append multiple objects.
    #
    # @param objs [Array<String, Placeholder, EncodedString>]
    # @return [self]
    def concat(*objs)
      objs.each do |obj|
        self << obj
      end
      self
    end

    # Append padding to align string to the specified word width.
    #
    # @param width [Integer]
    # @return [self]
    def align!(width = 4)
      rem = length % width
      self << ("\0" * (width - rem)) if rem.positive?

      self
    end

    # Length of this string.
    #
    # @return [Integer]
    def length
      @string.bytesize
    end

    # Raw string.
    #
    # @return [String]
    # @raise [UnresolvedPlaceholderError] if there are any unresolved
    #   placeholders left.
    def string
      unless placeholders.empty?
        raise UnresolvedPlaceholderError,
          "string contains #{placeholders.size} unresolved placeholder(s)"
      end

      @string
    end

    # Raw bytes.
    #
    # @return [Array<Integer>]
    # @raise [UnresolvedPlaceholderError] if there are any unresolved
    #   placeholders left.
    def bytes
      string.bytes
    end

    # Unresolved raw string.
    #
    # @return [String]
    def unresolved_string
      @string
    end

    # Resolve placeholder.
    #
    # @param name [Symbol]
    # @param value [String]
    # @return [void]
    def resolve_placeholder(name, value)
      return unless (placeholder = placeholders[name])

      value = value.byteslice(0, placeholder.length)
      @string[placeholder.position, value.bytesize] = value
      placeholders.delete(name)
    end

    # Plaholders
    #
    # @return [Hash{Symbol => Plaholder}]
    def placeholders
      @placeholders ||= {}
    end

    private

    def add_placeholder(new_placeholder, pos = @string.bytesize)
      if placeholders.include?(new_placeholder.name)
        raise DuplicatePlaceholderError,
          "placeholder #{new_placeholder.name} already exists"
      end

      new_placeholder.position = pos
      placeholders[new_placeholder.name] = new_placeholder
    end
  end
end
