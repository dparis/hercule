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

        # Raise an exception if no examples or labels were found, or
        # if for some reason the number of label entries and examples
        # don't match
        if labels.count == 0 || examples.count == 0 || (labels.count != examples.count)
          # TODO: Create custom exception class  --  Sat Mar  3 14:04:53 2012
          raise "Invalid amount of labels or examples: #{labels.count}/#{examples.count}"
        end

        # Create a new SVM problem based on the labels and associated
        # document feature vectors
        @svm_problem = Problem.new( labels, examples )
        
        # Train a new SVM model based on the problem and LibSVM param settings
        @svm_model = Model.new( @svm_problem, @svm_parameters )

        # Lock the associated document domain so that subsequent
        # documents don't affect the feature dictionary for the domain
        @trained_document_domain.lock

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

      def persist( options )
        # TODO: Wrap this in begin/rescue appropriately  --  Sat Mar  3 15:28:27 2012
        persist!( options )
      end

      def persist!( options )
        # Ensure that there's a trained model before attempting to
        # persist it
        # TODO: Define custom exception class  --  Sat Mar  3 13:25:21 2012
        unless trained?
          raise "Must train classifier before attempting to persist classification model"
        end
        
        if options[:file]
          # Persist to a file, so check if a filename was given,
          # otherwise derive one from the document domain id and
          # current time
          file_name = ''
          if options[:file].is_a?( String )
            # Strip any suffix if specified
            path, file_name = File.split( options[:file] )
            file_name = File.join( path, File.basename( file_name, '.*' ) )
          else
            file_name = [@trained_document_domain.id, Time.now.to_i].join( '_' )
          end

          # Persist the trained document domain
          File.open( file_name + '.dd', 'w' ) do |dd_file|
            Marshal.dump( @trained_document_domain, dd_file )
          end
          
          # Persist the trained LibSVM model
          @svm_model.save( file_name + '.svm' )
        end
      end

      def load( options )
        load_status = false
        
        begin
          load_status = load!( options )
        rescue TypeError => e
          # Marshal.load raises a type error if IO object is invalid,
          # or the mashaled data is incompatible/invalid, so ignore
          # those cases, otherwise raise the TypeError
          unless e.message =~ /^(instance of|incompatible marshal)/
            raise e
          end
        rescue Errno::ENOENT
          # Raised by File.open if the file doesn't exist
        rescue RuntimeError
          # If the svm file does not exist, this exception will be raised
          # TODO: This needs to be changed to a custom exception class  --  Sat Mar  3 15:23:39 2012
          unless e.message =~ /^LibSVM file not found/
            raise e
          end
        end

        return load_status
      end

      def load!( options )
        if options[:file]
          # Get the basename of the path specified
          path, file_name = File.split( options[:file] )
          file_name = File.join( path, File.basename( file_name, '.*' ) )

          # Begin loading process
          load_status = false

          # Load the document domain
          File.open( file_name + '.dd', 'r' ) do |file|
            @trained_document_domain = Marshal.load( file )
          end

          # Check that the LibSVM file exists before trying to load
          # it in order to prevent a segfault in the ruby runtime;
          # raise an exception if file not found
          unless File.exists?( file_name + '.svm' )
            # TODO: Create custom exception class  --  Sat Mar  3 15:23:22 2012
            raise "LibSVM file not found: #{file_name + '.svm'}"
          end

          # Load the trained LibSVM model
          # NOTE:  Be *very* careful here, libsvm may segfault if
          #        it tries to load an invalid file
          @svm_model = Model.new( file_name + '.svm' )

          # Register the trained document domain
          Hercule::Document.register_domain( @trained_document_domain )

          # Indicate that the classifier is trained
          @trained = true

          # Loading was successful, so update the load status
          load_status = true

          # Return the load status
          return load_status
        end
      end
    end
  end
end
