require 'svm'

require_relative 'base'

module Hercule
  module ClassifierEngines
    class LSVM < ClassifierEngines::Base
      #----------------------------------------------------------------------------
      # Attributes
      #----------------------------------------------------------------------------
      # NOTE:  SVM ATTRIBUTES ONLY FOR TESTING
      attr_reader :svm_model, :svm_problem, :svm_parameters

      #----------------------------------------------------------------------------
      # Instance Methods
      #----------------------------------------------------------------------------
      def initialize( options = {} )
        super( options )

        # Set up parameters for LibSVM
        reset_svm_parameters( options )
      end

      # Define a new parameters object using app defaults for values
      # not explicitly passed
      def reset_svm_parameters( options = {} )
        @svm_parameters = Parameter.new

        # For documentation regarding what these parameters do, see the
        # following links:
        # * http://www.csie.ntu.edu.tw/~cjlin/libsvm/
        # * https://github.com/tomz/libsvm-ruby-swig/blob/master/libsvm-3.1/ruby/README
        @svm_parameters.C          = options[:svm_c] || 10
        @svm_parameters.eps        = options[:svm_eps] || 0.001
        @svm_parameters.cache_size = options[:svm_cache_size] || 1 # In megabytes
      end

      def train( document_domain )
        super( document_domain )

        # Train all cached documents for the specified domain
        docs = document_domain.cache.values

        # Set up list of known labels and document feature vectors, with
        # each label entry matching the position of its associated
        # document feature vector
        labels, examples = [], []
        docs.each do |doc|
          if doc.label
            labels.push( document_domain.labels[doc.label] )
            examples.push( doc.feature_vector )
          end
        end

        # Create a new SVM problem based on the labels and associated
        # document feature vectors
        @svm_problem = Problem.new( labels, examples )
        
        # Train a new SVM model based on the problem and LibSVM param settings
        @svm_model = Model.new( @svm_problem, @svm_parameters )

        # Indicate that this classifer has been trained
        @trained = true
      end

      def classify( document )
        # Ensure that the classifer has been trained before attempting
        # to classify the document
        # TODO: Define custom exception type  --  Fri Mar  2 17:10:53 2012
        unless trained?
          raise "Must train classifier before attempting to classify document"
        end

        label_id = @svm_model.predict( document.feature_vector )

        # Set the document's label to the value associated with the
        # predicted label id
        document.label = @trained_document_domain.labels.key( label_id )

        # Return the newly labeled document and an empty hash as a
        # placeholder for the probability data
        return [document, {}]
      end

      def persist( options = {} )
        raise "Does nothing yet"
      end

      def load( options = {} )
        raise "Does nothing yet"
      end
    end
  end
end
