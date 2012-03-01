require 'gtokenizer'

module Hercule
  class Normalizer
    #----------------------------------------------------------------------------
    # Attributes
    #----------------------------------------------------------------------------
    attr_accessor :min_token_length, :strip_symbols, :strip_numerals,
                  :stem_words, :strip_stop_words, :stop_words
    
    #----------------------------------------------------------------------------
    # Instance Methods
    #----------------------------------------------------------------------------
    def initialize( options = {} )
      # Default minimum token length to 3
      @min_token_length = options[:min_token_length] || 3

      # Stem words by default
      @stem_words = options[:stem_words] || true

      # Strip symbols by default
      @strip_symbols = options[:strip_symbols] || true

      # Strip numerals by default
      @strip_numerals = options[:strip_numerals] || true

      # Strip stop words by default
      @strip_stop_words = options[:strip_stop_words] || true

      # Override the stop word array if specified
      @stop_words = options[:stop_words] || DEFAULT_STOP_WORDS
    end

    def normalize( text )
      # Strip symbols and numerals if configured to do so
      text.gsub!( /[^[:alnum:]|[:space:]]/, '' ) if @strip_symbols
      text.gsub!( /[[:digit:]]/, '' ) if @strip_numerals

      # Tokenize text and downcase each
      tokens = GTokenizer.parse( text )
      tokens.map!{ |t| t.downcase }

      # Strip out stop words if configured to do so
      tokens = (tokens - @stop_words) if @strip_stop_words

      # Remove tokens shorter than the minimum token length
      tokens.reject!{ |t| t.length < @min_token_length } if @min_token_length

      # Stem words if configured to do so
      tokens.map!{ |t| t.stem }  if @stem_words

      # Return normalized tokens
      return tokens
    end

    #----------------------------------------------------------------------------
    # Class Methods
    #----------------------------------------------------------------------------
    def tokenize( text )
      GTokenizer.parse( text )
    end

    def stem( word )
      word.stem
    end

    #----------------------------------------------------------------------------
    # Class Constants
    #----------------------------------------------------------------------------
    DEFAULT_STOP_WORDS = %w[ a able about across after all almost 
                             also am among an and any are as at be
                             because been but by can cannot could
                             dear did do does either else ever every
                             for from get got had has have he her
                             hers him his how however i if in into
                             is it its just least let like likely
                             may me might most must my neither no nor
                             not of off often on only or other our
                             own rather said say says she should
                             since so some than that the their
                             them then there these they this tis to
                             too twas us wants was we were what when
                             where which while who whom why will with
                             would yet you your ]
  end
end
