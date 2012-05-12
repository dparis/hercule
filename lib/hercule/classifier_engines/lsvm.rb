require 'svm'
require 'mongo' # OPTIMIZE: Make mongo optional requirement?  --  Sun Mar 25 15:12:58 2012
require 'tempfile'

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
      # Class Constants
      #----------------------------------------------------------------------------
      DEFAULT_MONGODB_NAME = 'hercule_lsvm_classifiers'      

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

        # OPTIMIZE: libsvm-ruby-swig needs to be patched to make the
        # svm_check_probability_model method directly available through the
        # Model class interface
        probability_enabled = ( @svm_model.instance_variable_get( :@probability ) == 1 ? true : false )
        if probability_enabled
          label_id, raw_probabilities = @svm_model.predict_probability( document.feature_vector )

          # Map the class ids to the known labels in the document domain
          raw_probabilities.each do |id, prob|
            # OPTIMIZE: Kind of bad, should probably refactor the
            # domain.labels code  --  Sun Mar  4 21:47:42 2012
            label = labels.key(id)

            probabilities[label] = prob
          end          
        else
          label_id = @svm_model.predict( document.feature_vector )
        end

        # Set the document's label to the value associated with the
        # predicted label id
        # OPTIMIZE: Kind of bad, should probably refactor the
        # domain.labels code  --  Sun Mar  4 21:47:42 2012
        document.label = labels.key( label_id )

        # Return the newly labeled document and an empty hash as a
        # placeholder for the probability data
        return [document.label, probabilities]
      end

      # OPTIMIZE: Refactor load/persist options hash format  --  Sun Mar 25 20:23:07 2012
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
          persist_status = file_name
        elsif options[:gridfs]
          # Persist to a GridFS store
          mongo_connection = options[:gridfs]

          # Ensure that the object passed is a valid mongo db
          # connection object
          unless mongo_connection.is_a?( Mongo::Connection )
            raise Hercule::ClassifierError, 'Must pass a valid Mongo::Connection instance if :gridfs is specified'
          end

          # Open a connection to the underlying mongo database based
          # on either the specified db name or the default mongodb
          # name defined by the class constant
          db_name = options[:gridfs_db_name] || DEFAULT_MONGODB_NAME
          grid_fs = Mongo::GridFileSystem.new( mongo_connection.db( db_name ) )

          # Process the filename if specified, or derive one from the
          # document domain
          file_name = ''
          if options[:gridfs_filename].is_a?( String )
            # Strip any suffix if specified
            file_name = File.basename( options[:gridfs_filename], '.*' )
          else
            file_name = [@trained_document_domain.id].join( '_' )
          end

          # Persist the trained document domain
          # TODO: Add support for optionally deleting old versions  --  Sun Mar 25 20:30:14 2012
          marshalled_domain = Marshal.dump( @trained_document_domain )
          grid_fs.open( file_name + '.dd', 'w', :safe => true ) do |file|
            file.write( marshalled_domain )
          end

          # Persist the trained LibSVM model
          # OPTIMIZE: This is clunky, maybe find a better way to get LibSVM
          # to save model data  --  Sun Mar 25 17:38:41 2012
          begin
            temp_file = Tempfile.new( file_name )
            temp_file.close

            # Save the LibSVM model data to the tempfile
            if @svm_model.save( temp_file.path ) == -1
              raise Hercule::ClassifierError, "Could not save LibSVM model to file: #{temp_file}.svm"
            end

            # Re-open the tempfile and write the data to GridFS
            temp_file.open
            temp_file.rewind
            
            grid_fs.open( file_name + '.svm', 'w' ) do |file|
              file.write( temp_file.read )
            end
          ensure
            temp_file.close
            temp_file.unlink
          end

          # Set the persist status
          persist_status = file_name
        else
          raise Hercule::ClassifierError, 'Must specify a valid persistence mechanism' 
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
        # Begin loading process
        load_status = false

        if options[:file]
          # Get the basename of the path specified
          path, file_name = File.split( options[:file] )
          file_name = File.join( path, File.basename( file_name, '.*' ) )

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
        elsif options[:gridfs]
          # Load from a GridFS store
          mongo_connection = options[:gridfs]

          # Ensure that the object passed is a valid mongo db
          # connection object
          unless mongo_connection.is_a?( Mongo::Connection )
            raise Hercule::ClassifierError, 'Must pass a valid Mongo::Connection instance if :gridfs is specified'
          end

          # Get the basename of the path specified
          unless options[:gridfs_filename].is_a?( String )
            raise Hercule::ClassifierError, 'Must pass :gridfs_filename when loading from GridFS'
          end

          file_name = File.basename( options[:gridfs_filename], '.*' )

          begin
            # Open a connection to the underlying mongo database based
            # on either the specified db name or the default mongodb
            # name defined by the class constant
            db_name = options[:gridfs_db_name] || DEFAULT_MONGODB_NAME
            grid_fs = Mongo::GridFileSystem.new( mongo_connection.db( db_name ) )

            # Load the document domain
            @trained_document_domain = Marshal.load( grid_fs.open( file_name + '.dd', 'r' ) { |file| file.read } )
          
            # Load the LibSVM model data from GridFS
            model_data = grid_fs.open( file_name + '.svm', 'r' ) { |file| file.read }

            # Check that the LibSVM file exists before trying to load
            # it in order to prevent a segfault in the ruby runtime;
            # raise an exception if file not found
            unless model_data
              raise Hercule::ClassifierError, "LibSVM file not found in specified database: #{file_name + '.svm'}"
            end

            # Load the model_data into a tempfile so it can be read by libsvm-ruby-swig
            begin
              temp_file = Tempfile.new( file_name )
              temp_file.write( model_data )
              temp_file.close

              # Load the trained LibSVM model
              # NOTE:  Be *very* careful here, libsvm may segfault if
              #        it tries to load an invalid file
              # OPTIMIZE: Write validator for LibSVM model file  --  Sun Mar 25 20:55:08 2012
              @svm_model = Model.new( temp_file.path )
            ensure
              temp_file.close
              temp_file.unlink
            end
          rescue TypeError => e
            # Marshal.load raises a type error if IO object is invalid,
            # or the mashaled data is incompatible/invalid, so ignore
            # those cases, otherwise raise the TypeError
            if e.message =~ /^(instance of|incompatible marshal)/
              raise Hercule::ClassifierError, 'Marshalled domain invalid'
            else
              raise e
            end
          rescue Mongo::GridFileNotFound
            raise Hercule::ClassifierError, "Marshalled domain not found in specified database: #{file_name + '.dd'}"
          rescue Mongo::InvalidNSName => e
            raise Hercule::ClassifierError, e.message
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
