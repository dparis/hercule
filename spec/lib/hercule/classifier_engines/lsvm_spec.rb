require 'spec_helper'

describe Hercule::ClassifierEngines::LSVM do
  it_behaves_like 'classifier engine'

  before(:each) do
    @lsvm_c = Hercule::ClassifierEngines::LSVM.new

    @feature_string = 'Some text for testing text features'
    @label = :test_label
    @doc = Hercule::Document.new( @feature_string, :label => @label )
    @doc_domain = @doc.current_domain
  end

  context 'initialization' do
    it 'should set up LibSVM default parameters' do
      lsvm_classifier = Hercule::ClassifierEngines::LSVM.new

      lsvm_classifier.svm_parameters.should be_a( Parameter )
      svmp = lsvm_classifier.svm_parameters

      svmp.C.should == 10
      svmp.eps.should == 0.001
      svmp.cache_size.should == 1
      svmp.probability.should == 1
    end

    context 'options' do
      it 'should set the C value' do
        lsvm_classifier = Hercule::ClassifierEngines::LSVM.new( :svm_c => 2 )
        lsvm_classifier.svm_parameters.C.should == 2
      end

      it 'should set the eps value' do
        lsvm_classifier = Hercule::ClassifierEngines::LSVM.new( :svm_eps => 0.005 )
        lsvm_classifier.svm_parameters.eps.should == 0.005
      end

      it 'should set the cache_size value' do
        lsvm_classifier = Hercule::ClassifierEngines::LSVM.new( :svm_cache_size => 2 )
        lsvm_classifier.svm_parameters.cache_size.should == 2
      end

      it 'should set the probability value' do
        lsvm_classifier = Hercule::ClassifierEngines::LSVM.new( :svm_calc_probabilities => 0 )
        lsvm_classifier.svm_parameters.probability.should == 0
      end
    end
  end

  context 'train method' do
    it 'should raise a HerculeClassifierError exception if the document domain has no documents' do
      empty_domain = Hercule::Document::Domain.new( :empty_domain )
      expect{ @lsvm_c.train( empty_domain ) }.to raise_exception( Hercule::ClassifierError )
    end

    it 'should mark the classifier as trained' do
      @lsvm_c.train( @doc_domain )
      @lsvm_c.should be_trained
    end

    it 'should lock the trained document domain' do
      @doc_domain.should_not be_locked
      @lsvm_c.train( @doc_domain )
      @doc_domain.should be_locked
    end

    it 'should set svm_problem' do
      @lsvm_c.train( @doc_domain )
      @lsvm_c.svm_problem.should be_a( Problem )
    end

    it 'should set svm_model' do
      @lsvm_c.train( @doc_domain )
      @lsvm_c.svm_model.should be_a( Model )
    end
  end

  context 'classify method' do
    it 'should raise a Hercule::ClassifierError exception if classifier is not trained' do
      @lsvm_c.should_not be_trained
      expect{ @lsvm_c.classify( @doc ) }.to raise_exception( Hercule::ClassifierError )
    end

    # TODO: Spec to check for reasonable results  --  Fri Mar 23 19:36:01 2012
  end

  context 'persist! method' do
    it 'should raise a Hercule::ClassifierError exception if classifier is not trained' do
      @lsvm_c.should_not be_trained
      expect{ @lsvm_c.persist!( :file => 'test' ) }.to raise_exception( Hercule::ClassifierError )
    end

    it 'should raise a Hercule::ClassifierError exception if no valid persistence method is specified' do
      expect{ @lsvm_c.persist!( :invalid_persistence_method => nil ) }.to raise_exception( Hercule::ClassifierError )
    end

    context 'when a file is specified' do
      before(:each) do
        @lsvm_c.train( @doc_domain )
      end
      
      context 'when the filename and path is valid' do
        it 'should save the LibSVM model and document domain to the filesystem' do
          @lsvm_c.persist!( :file => 'spec/support/temp' )
          File.exists?( 'spec/support/temp.dd' ).should be_true
          File.exists?( 'spec/support/temp.svm' ).should be_true

          # Clean up temp files
          File.delete( 'spec/support/temp.dd' )
          File.delete( 'spec/support/temp.svm' )
        end

        it 'should return the path and basename of the files saved' do
          returned_name = @lsvm_c.persist!( :file => 'spec/support/temp' )
          returned_name.should == 'spec/support/temp'

          # Clean up temp files
          File.delete( 'spec/support/temp.dd' )
          File.delete( 'spec/support/temp.svm' )
        end          
      end

      context 'when the filename and path is not valid' do
        it 'should raise an exception' do
          expect{ @lsvm_c.persist!( :file => 'invalid_path/invalid_filename' ) }.to raise_exception( Hercule::ClassifierError )
        end
      end
    end

    context 'when GridFS is specified' do
      before(:each) do
        @lsvm_c.train( @doc_domain )

        @gridfs_filename = 'lsvm_classifier_test'
        @gridfs_db_name = 'hercule_lsvm_classifiers_test'
        
        @mongo_connection = Mongo::Connection.new

        @grid_fs = Mongo::GridFileSystem.new( @mongo_connection.db( @gridfs_db_name ) )
        @grid_fs.delete( @gridfs_filename )
      end

      it 'should raise a Hercule::ClassifierError if a valid MongoDB connection object is not passed' do
        expect{ @lsvm_c.persist!( :gridfs => nil ) }.to raise_exception( Hercule::ClassifierError )
        expect{ @lsvm_c.persist!( :gridfs => 'not_a_mongodb_connection' ) }.to raise_exception( Hercule::ClassifierError )
      end

      context 'when the filename is specified and valid' do
        it 'should save the LibSVM model and document domain to the specified MongoDB using GridFS' do
          @lsvm_c.persist!( :gridfs => @mongo_connection,
                            :gridfs_filename => @gridfs_filename,
                            :gridfs_db_name => @gridfs_db_name )

          @grid_fs.open( @gridfs_filename + '.dd', 'r' ).should be_a( Mongo::GridIO )
          @grid_fs.open( @gridfs_filename + '.svm', 'r' ).should be_a( Mongo::GridIO )
        end

        it 'should return the basename of the GridFS files saved' do
          returned_name = @lsvm_c.persist!( :gridfs => @mongo_connection,
                                            :gridfs_filename => @gridfs_filename,
                                            :gridfs_db_name => @gridfs_db_name )

          returned_name.should == @gridfs_filename
        end
      end

      after(:each) do
        @mongo_connection.drop_database( @gridfs_db_name )
      end
    end
  end

  # OPTIMIZE: Refactor load/persist method specs into shared examples  --  Sun Mar 25 14:40:26 2012
  context 'persist method' do
    context 'when persist! method returns a Hercule::ClassifierEngines exception' do
      before(:each) do
        @lsvm_c.stub( :persist! ).and_raise( Hercule::ClassifierError )
      end

      it 'should return false' do
        @lsvm_c.persist( :file => 'invalid_path/invalid_filename' ).should be_false
      end
    end

    context 'when persist! method returns an unexpected, unrelated exception' do
      before(:each) do
        @lsvm_c.stub( :persist! ).and_raise( Exception )
      end

      it 'should raise the unhandled exception' do
        expect{ @lsvm_c.persist( :file => 'invalid_path/invalid_filename' ) }.to raise_exception
      end
    end

    context 'when persist! method returns normally' do
      it 'should return the status of the persist attempt' do
        @lsvm_c.stub( :persist! ).and_return( true )
        @lsvm_c.persist( :file => 'spec/support/temp.svm' ).should be_true

        @lsvm_c.stub( :persist! ).and_return( false )
        @lsvm_c.persist( :file => 'invalid_path/invalid_filename' ).should be_false
      end
    end
  end

  context 'load! method' do
    before(:each) do
      @new_lsvm_c = Hercule::ClassifierEngines::LSVM.new
    end

    context 'when a file is specified' do
      context 'when the filename and path are valid' do
        before(:each) do
          Hercule::Document.deregister_domain( @doc_domain )
          Hercule::Document.find_domain( @doc_domain.id ).should be_nil
          
          @lsvm_c.train( @doc_domain )
          @lsvm_c.persist!( :file => 'spec/support/temp' )
        end

        it 'should register the loaded document domain' do
          @new_lsvm_c.load!( :file => 'spec/support/temp' )
          
          registered_domain = Hercule::Document.find_domain( @doc_domain.id )
          registered_domain.should be_a( Hercule::Document::Domain )
          registered_domain.id.should == @doc_domain.id
        end

        it 'should load the LibSVM model' do
          @new_lsvm_c.svm_model.should be_nil
          @new_lsvm_c.load!( :file => 'spec/support/temp' )
          @new_lsvm_c.svm_model.should be_a( Model )
        end

        after(:each) do
          # Clean up temp files
          File.delete( 'spec/support/temp.dd' )
          File.delete( 'spec/support/temp.svm' )
        end
      end

      context 'when the filename and path are not valid' do
        it 'should raise an exception' do
          expect{ @new_lsvm_c.load!( :file => 'invalid_path/invalid_filename' ) }.to raise_exception( Hercule::ClassifierError )
        end
      end
    end

    context 'when GridFS is specified' do
      before(:each) do
        @mongo_connection = Mongo::Connection.new
      end

      context 'when the filename and database name are valid' do
        before(:each) do
          Hercule::Document.deregister_domain( @doc_domain )
          Hercule::Document.find_domain( @doc_domain.id ).should be_nil

          @gridfs_filename = 'lsvm_classifier_test'
          @gridfs_db_name = 'hercule_lsvm_classifiers_test'
          
          @lsvm_c.train( @doc_domain )
          @lsvm_c.persist!( :gridfs => @mongo_connection,
                            :gridfs_filename => @gridfs_filename,
                            :gridfs_db_name => @gridfs_db_name )

          @grid_fs = Mongo::GridFileSystem.new( @mongo_connection.db( @gridfs_db_name ) )
        end

        it 'should register the loaded document domain' do
          @new_lsvm_c.load!( :gridfs => @mongo_connection,
                             :gridfs_filename => @gridfs_filename,
                             :gridfs_db_name => @gridfs_db_name )
          
          registered_domain = Hercule::Document.find_domain( @doc_domain.id )
          registered_domain.should be_a( Hercule::Document::Domain )
          registered_domain.id.should == @doc_domain.id
        end

        it 'should load the LibSVM model' do
          @new_lsvm_c.svm_model.should be_nil

          @new_lsvm_c.load!( :gridfs => @mongo_connection,
                             :gridfs_filename => @gridfs_filename,
                             :gridfs_db_name => @gridfs_db_name )

          @new_lsvm_c.svm_model.should be_a( Model )
        end

        after(:each) do
          @mongo_connection.drop_database( @gridfs_db_name )
        end
      end

      context 'when the filename or database name are not valid' do
        it 'should raise an exception if the filename is invalid' do
          expect{ @new_lsvm_c.load!( :gridfs => @mongo_connection,
                                     :gridfs_filename => '',
                                     :gridfs_db_name => 'valid_db_name'  ) }.to raise_exception( Hercule::ClassifierError )
        end

        it 'should raise an exception if the database name is invalid' do
          expect{ @new_lsvm_c.load!( :gridfs => @mongo_connection,
                                     :gridfs_filename => 'valid_filename',
                                     :gridfs_db_name => ' invalid db name'  ) }.to raise_exception( Hercule::ClassifierError )
        end
      end
    end
  end

  # OPTIMIZE: Refactor load/persist method specs into shared examples  --  Sun Mar 25 14:40:26 2012
  context 'load method' do
    context 'when load! method returns a Hercule::ClassifierEngines exception' do
      before(:each) do
        @lsvm_c.stub( :load! ).and_raise( Hercule::ClassifierError )
      end

      it 'should return false' do
        @lsvm_c.load( :file => 'invalid_path/invalid_filename' ).should be_false
      end
    end

    context 'when load! method returns an unexpected, unrelated exception' do
      before(:each) do
        @lsvm_c.stub( :load! ).and_raise( Exception )
      end

      it 'should raise the unhandled exception' do
        expect{ @lsvm_c.load( :file => 'invalid_path/invalid_filename' ) }.to raise_exception
      end
    end

    context 'when load! method returns normally' do
      it 'should return the status of the load attempt' do
        @lsvm_c.stub( :load! ).and_return( true )
        @lsvm_c.load( :file => 'spec/support/temp.svm' ).should be_true

        @lsvm_c.stub( :load! ).and_return( false )
        @lsvm_c.load( :file => 'invalid_path/invalid_filename' ).should be_false
      end
    end
  end

  after(:each) do
    Hercule::Document.deregister_domain( @doc_domain )
  end
end
