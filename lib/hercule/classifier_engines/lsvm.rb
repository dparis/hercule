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
        @svm_parameters.C           = options[:svm_c] || 10
        @svm_parameters.eps         = options[:svm_eps] || 0.001
        @svm_parameters.cache_size  = options[:svm_cache_size] || 1 # In megabytes
        @svm_parameters.probability = options[:svm_calc_probabilities] || 1
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
          raise Hercule::ClassifierError, "Invalid amount of labels or examples: #{labels.count}/#{examples.count}"
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
        unless trained?
          raise Hercule::ClassifierError, "Must train classifier before attempting to classify document"
        end

        # If the model was configured to calculate probabilities,
        # predict probabilities, otherwise just get a label prediction
        probabilities = {}
        label_id = nil
        labels = @trained_document_domain.labels

        # TODO: Figure out if there's a way to get this flag off the model  --  Sun Mar  4 20:38:21 2012
        if @svm_parameters.probability == 1
          label_id, raw_probabilities = @svm_model.predict_probability( document.feature_vector )

          # Map the class ids to the known labels in the document domain
          raw_probabilities.each do |id, prob|
            # TODO: Kind of bad, should probably refactor the
            # domain.labels code  --  Sun Mar  4 21:47:42 2012
            label = labels.key(id)

            probabilities[label] = prob
          end          
        else
          label_id = @svm_model.predict( document.feature_vector )
        end

        # Set the document's label to the value associated with the
        # predicted label id
        # TODO: Kind of bad, should probably refactor the
        # domain.labels code  --  Sun Mar  4 21:47:42 2012
        document.label = labels.key( label_id )

        # Return the newly labeled document and an empty hash as a
        # placeholder for the probability data
        return [document, probabilities]
      end

      def persist( options )
        persist_status = false
        
        begin
          persist_status = persist!( options )
        rescue Hercule::ClassifierError
        end

        return persist_status
      end

      def persist!( options )
        persist_status = false

        # Ensure that there's a trained model before attempting to
        # persist it
        unless trained?
          raise Hercule::ClassifierError, "Must train classifier before attempting to persist classification model"
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

          begin
            # Persist the trained document domain
            File.open( file_name + '.dd', 'w' ) do |dd_file|
              Marshal.dump( @trained_document_domain, dd_file )
            end
            
            # Persist the trained LibSVM model
            if @svm_model.save( file_name + '.svm' ) == -1
              raise Hercule::ClassifierError, "Could not save LibSVM model to file: #{file_name}.svm"
            end
          rescue Errno::ENOENT
            # Raised by File.open if the file doesn't exist
            raise Hercule::ClassifierError, "File could not be created: #{file_name}.dd"
          rescue Hercule::ClassifierError => e
            raise e
          end
          
          # Classifier was persisted successfully, so update the
          # persist status
          persist_status = true
        end

        # Return the persist status
        return persist_status
      end

      def load( options )
        load_status = false
        
        begin
          load_status = load!( options )
        rescue Hercule::ClassifierError
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

          begin
            # Load the document domain
            File.open( file_name + '.dd', 'r' ) do |file|
              @trained_document_domain = Marshal.load( file )
            end

            # Check that the LibSVM file exists before trying to load
            # it in order to prevent a segfault in the ruby runtime;
            # raise an exception if file not found
            unless File.exists?( file_name + '.svm' )
              raise Hercule::ClassifierError, "LibSVM file not found: #{file_name + '.svm'}"
            end

            # Load the trained LibSVM model
            # NOTE:  Be *very* careful here, libsvm may segfault if
            #        it tries to load an invalid file
            @svm_model = Model.new( file_name + '.svm' )
          rescue TypeError => e
            # Marshal.load raises a type error if IO object is invalid,
            # or the mashaled data is incompatible/invalid, so ignore
            # those cases, otherwise raise the TypeError
            if e.message =~ /^(instance of|incompatible marshal)/
              raise Hercule::ClassifierError, 'Marshalled domain invalid'
            else
              raise e
            end
          rescue Errno::ENOENT
            # Raised by File.open if the file doesn't exist
            raise Hercule::ClassifierError, "File not found: #{file_name}.dd"
          rescue Hercule::ClassifierError => e
            raise e
          end
          
          # Register the trained document domain
          Hercule::Document.register_domain( @trained_document_domain )

          # Indicate that the classifier is trained
          @trained = true

          # Loading was successful, so update the load status
          load_status = true
        end

        # Return the load status
        return load_status
      end
    end
  end
end
