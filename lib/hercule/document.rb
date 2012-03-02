require 'uuid'

module Hercule
  class Document
    #----------------------------------------------------------------------------
    # Class Constants
    #----------------------------------------------------------------------------
    DEFAULT_DOMAIN_ID = :training

    #----------------------------------------------------------------------------
    # Class Variables
    #----------------------------------------------------------------------------

    # This is a hash of Document::Domain objects, keyed off domain values
    @@document_domains = {}

    #----------------------------------------------------------------------------
    # Attributes
    #----------------------------------------------------------------------------
    attr_reader :feature_vector, :feature_list, :id, :metadata
    
    def initialize( features, options = {} )
      # Set up default values
      @feature_vector = []
      @domain_id = options[:domain_id] || DEFAULT_DOMAIN_ID
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
      
      # Rebuild the feature dictionary if the current domain is not locked
      rebuild_feature_dictionary unless current_domain.locked?
      
      # Calculate the feature vector
      calculate_feature_vector
    end

    def current_domain
      @@document_domains[@domain_id]
    end

    def feature_dictionary
      current_domain.dictionary
    end

    #----------------------------------------------------------------------------
    # Class Methods
    #----------------------------------------------------------------------------
    # TODO: FIX THIS  --  Fri Mar  2 13:49:29 2012
    class << self
      def define_feature_dictionary( feature_dictionary, domain = nil )
        domain ||= DEFAULT_DOMAIN_ID
        @@feature_dictionary[domain] = feature_dictionary
      end
    end

    #----------------------------------------------------------------------------
    # Protected Instance Methods
    #----------------------------------------------------------------------------
    protected

    def cache_document
      # Instantiate a new Domain with the given id unless the class
      # variable already has the key
      unless @@document_domains.has_key?( @domain_id )
        @@document_domains[@domain_id] = Domain.new( @domain_id )
      end

      domain = @@document_domains[@domain_id]
      domain.cache[@id] = self
    end

    # Rebuild the feature dictionary from the document cache
    # associated with this instance's domain, and then rebuild all
    # feature vectors for documents in this domain
    def rebuild_feature_dictionary
      if current_domain.locked?
        warn "[HERCULE] attempt to rebuild feature dictionary for locked domain '#{@domain}'"
        return
      end
      
      # Extract the document instances from the cache hash values
      docs = current_domain.cache.values

      # Compile a list of unique features from each cached doc
      feature_dictionary = current_domain.dictionary
      
      max_dict_id = feature_dictionary.keys.max || -1

      docs.each do |doc|
        # Iterate all features for this doc instance, and unless the
        # dictionary already contains the feature, add it and assign a
        # new feature id
        doc.feature_list.each do |feature|
          unless feature_dictionary.has_value?( feature )
            max_dict_id += 1
            feature_dictionary[max_dict_id] = feature
          end
        end
      end

      # Rebuild all feature vectors for documents in this domain
      docs.each{ |doc| doc.calculate_feature_vector }
    end

    # Calculate the feature vector for the document's features using a
    # TF-IDF approach
    # NOTE: Consider using a BNS feature scaling approach - See paper
    # by G. Forman, http://goo.gl/igUJ0
    def calculate_feature_vector
      fd = current_domain.dictionary
      fd_ids = fd.keys.sort

      @feature_vector = fd_ids.map do |fd_id|
        feature = fd[fd_id]
        @feature_list.include?( feature ) ? 1 : 0 # TODO: TF-IDF here  --  Thu Mar  1 19:25:21 2012
      end
    end

    #----------------------------------------------------------------------------
    # Nested Classes
    #----------------------------------------------------------------------------
    class Domain

      #----------------------------------------------------------------------------
      # Attributes
      #----------------------------------------------------------------------------
      attr_accessor :id, :cache, :dictionary

      #----------------------------------------------------------------------------
      # Instance Methods
      #----------------------------------------------------------------------------
      def initialize( id, cache = {}, dictionary = {} )
        # The id of this document domain, should be unique within the
        # scope of a single app
        @id = id

        # Hash of document instances keyed off of the document id
        @cache = cache

        # Hash of features for this document domain, keyed off of the
        # id of the feature, which should map to the document vector position
        # for that feature
        @dictionary = dictionary

        # Bool to indicate lock state
        @locked = false
      end

      def locked?
        @locked
      end

      def lock
        @locked = true
      end

      def unlock
        @locked = false
      end
    end
  end
end
