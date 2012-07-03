require 'gtokenizer'
require 'fast_stemmer'
require 'nokogiri'

module Hercule
  class Preprocessor
    #----------------------------------------------------------------------------
    # Attributes
    #----------------------------------------------------------------------------
    attr_accessor :min_token_length, :strip_symbols, :strip_numerals,
                  :stem_words, :strip_stop_words, :stop_words
    
    #----------------------------------------------------------------------------
    # Instance Methods
    #----------------------------------------------------------------------------
    def initialize( options = {} )
      # Insert default values into options hash
      options = {
        :min_token_length => 3,
        :stem_words => true,
        :strip_symbols => true,
        :strip_numerals => true,
        :strip_stop_words => true,
        :stop_words => DEFAULT_STOP_WORDS
      }.merge( options )

      # Default minimum token length to 3
      @min_token_length = options[:min_token_length]

      # Stem words by default
      @stem_words = options[:stem_words]

      # Strip symbols by default
      @strip_symbols = options[:strip_symbols]

      # Strip numerals by default
      @strip_numerals = options[:strip_numerals]

      # Strip stop words by default
      @strip_stop_words = options[:strip_stop_words]

      # Override the stop word array if specified
      @stop_words = options[:stop_words]
    end

    def preprocess( text )
      # Strip symbols and numerals if configured to do so
      text = text.gsub( /[^[:alnum:]|[:space:]]/, '' ) if @strip_symbols
      text = text.gsub( /[[:digit:]]/, '' ) if @strip_numerals

      # Tokenize text and downcase each
      tokens = GTokenizer.parse( text )
      tokens.map!{ |t| t.downcase }

      # Strip out stop words if configured to do so
      tokens = (tokens - @stop_words) if @strip_stop_words

      # Stem words if configured to do so
      tokens.map!{ |t| t.stem } if @stem_words

      # Remove tokens shorter than the minimum token length
      tokens.reject!{ |t| t.length < @min_token_length } if @min_token_length

      # Return processed tokens
      return tokens
    end

    #----------------------------------------------------------------------------
    # Class Methods
    #----------------------------------------------------------------------------
    class << self
      def tokenize( text )
        GTokenizer.parse( text )
      end

      def stem( word )
        word.stem
      end

      def extract_text_from_html( html )
        # Convert parameter to nokogiri doc if it isn't already
        html = html.to_html if html.is_a?( Nokogiri::HTML::Document )

        # Re-parse HTML content so as to strip out blanks and
        # entities, supressing errors related to malformed HTML
        html = Nokogiri::HTML( html ) do |config|
          config.noent.noblanks.noerror
        end

        # Strip out media tags and styling
        html.search( "//script","//img","//iframe","//object","//embed","//param","//form","//meta","//link","//title" ).remove
        html.search( "//div","//p","//span","//a","//h1","//h2","//h3","//h4","//h5","//h6","//ul","//ol" ).attr( 'class', '' ).attr( 'id', '' ).attr( 'style', '' )

        # Collect all readable text chunks from the document
        readable_text = []
        html.traverse do |node|
          if node.text? && !node.text.strip.empty?
            # Assume node is readable text by default
            is_readable = true

            # Allow for a block to determine whether the node text is readable
            is_readable = yield( node.text ) if block_given?
            
            # Add the node text to the list if it's still considered readable
            readable_text << node.text if is_readable
          end
        end

        # Join all readable text instances with newlines
        readable_text.join("\n")
      end
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
