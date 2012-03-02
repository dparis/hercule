require 'uuid'

module Hercule
  class Document
    #----------------------------------------------------------------------------
    # Class Constants
    #----------------------------------------------------------------------------
    DEFAULT_DOMAIN = :default

    #----------------------------------------------------------------------------
    # Class Variables
    #----------------------------------------------------------------------------

    # The feature dictionary contains all unique tokens in the corpus
    # scoped to the document domain, key misses should result in an empty hash
    @@feature_dictionary = Hash.new{ |h, k| h[k] = {} }

    # The document cache should hold a hash of uniquely indexed hashes
    # of docment instances, key misses should result in an empty hash
    @@document_cache = Hash.new{ |h, k| h[k] = {} }

    #----------------------------------------------------------------------------
    # Attributes
    #----------------------------------------------------------------------------
    attr_reader :feature_vector, :feature_list, :id, :metadata
    
    def initialize( features, options = {} )
      # Set up default values
      @feature_vector = []
      @domain = options[:domain] || DEFAULT_DOMAIN
      @id = options[:id] || UUID.new
      @metadata = options[:metadata] || nil

      # Handle a string or a feature array
      if features.is_a?( String )
        # Stash and preprocess the document features
        @raw_text = features

        p = Hercule::Preprocessor.new
        @feature_list = p.preprocess( @raw_text )
      elsif features.is_a?( Array )
        # Assume the feature array is already preprocessed, so
        # approximate the raw text and stash the array
        @raw_text = features.join( ' ' )
        @feature_list = features
      end

      # Add self to document cache
      cache_document
      
      # Rebuild the feature dictionary
      rebuild_feature_dictionary
      
      # Calculate the feature vector
      calculate_feature_vector
    end

    def feature_dictionary
      @@feature_dictionary[@domain]
    end

    #----------------------------------------------------------------------------
    # Class Methods
    #----------------------------------------------------------------------------
    class << self
      def define_feature_dictionary( feature_dictionary, domain = nil )
        domain ||= DEFAULT_DOMAIN
        @@feature_dictionary[domain] = feature_dictionary
      end
    end

    #----------------------------------------------------------------------------
    # Protected Instance Methods
    #----------------------------------------------------------------------------
    protected

    def cache_document
      @@document_cache[@domain][@id] = self      
    end

    # Rebuild the feature dictionary from the document cache
    # associated with this instance's domain, and then rebuild all
    # feature vectors for documents in this domain
    def rebuild_feature_dictionary
      docs = @@document_cache[@domain]

      # Compile a list of unique features from each cached doc
      feature_dictionary = docs.values.inject([]){ |dict, doc| dict += doc.feature_list }
      feature_dictionary = feature_dictionary.flatten.uniq

      # Stash the newly rebuilt feature dictionary
      @@feature_dictionary[@domain] = feature_dictionary

      # Rebuild all feature vectors for documents in this domain
      docs.values.each{ |doc| doc.calculate_feature_vector }
    end

    # Calculate the feature vector for the document's features using a
    # TF-IDF approach
    # NOTE: Consider using a BNS feature scaling approach - See paper
    # by G. Forman, http://goo.gl/igUJ0
    def calculate_feature_vector
      fd = @@feature_dictionary[@domain].map

      @feature_vector = fd.map do |dict_entry|
        @feature_list.include?( dict_entry ) ? 1 : 0 # TODO: TF-IDF here  --  Thu Mar  1 19:25:21 2012
      end
    end
  end
end
