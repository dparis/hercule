require 'spec_helper'

describe 'Hercule' do
  context '::Document' do
    before(:each) do
      @feature_string = 'Some text for testing text features'
      @feature_array = %w[text test text featur]

      @feature_list_result = %w[text test text featur]
      @feature_vector = [1, 1, 1]

      @domain_id = :test_domain_id
      @label = :test_label
      @id = :test_id
      
      @metadata = { :test => 1234 }

      @doc = Hercule::Document.new( @feature_string, :label => @label )
    end

    context 'class constants' do
      it 'should define a default domain id' do
        Hercule::Document.const_defined?( :DEFAULT_DOMAIN_ID ).should be_true
      end
    end

    context 'attributes' do
      it 'should allow only reading of feature vector' do
        @doc.should respond_to( :feature_vector )
        @doc.should_not respond_to( :feature_vector= )
      end

      it 'should allow only reading of feature list' do
        @doc.should respond_to( :feature_list )
        @doc.should_not respond_to( :feature_list= )
      end

      it 'should allow only reading of document id' do
        @doc.should respond_to( :id )
        @doc.should_not respond_to( :id= )
      end

      it 'should provide access to label' do
        @doc.label = @label
        @doc.label.should == @label
      end

      it 'should provide access to metadata' do
        @doc.metadata = @metadata
        @doc.metadata.should == @metadata
      end
    end

    context 'registered domains' do
      it 'should register by passing a domain id' do
        registered_domain = Hercule::Document.register_domain( @domain_id )
        registered_domain.should be_a( Hercule::Document::Domain )
        Hercule::Document.find_domain( @domain_id ).should == registered_domain
      end
      
      it 'should register by passing a Domain instance' do
        new_domain = Hercule::Document::Domain.new( :domain_id )
        registered_domain = Hercule::Document.register_domain( new_domain )
        new_domain.should == registered_domain
        Hercule::Document.find_domain( :domain_id ).should == registered_domain
      end

      it 'should be searchable by domain id' do
        new_doc = Hercule::Document.new( @feature_string, :domain_id => @domain_id )
        domain = Hercule::Document.find_domain( @domain_id )
        domain.should be_a( Hercule::Document::Domain )
        domain.id.should == @domain_id
      end

      it 'should deregister by domain id' do
        registered_domain = Hercule::Document.register_domain( @domain_id )
        registered_domain.should be_a( Hercule::Document::Domain )
        
        Hercule::Document.deregister_domain( registered_domain.id )
        no_domain = Hercule::Document.find_domain( @domain_id )
        no_domain.should be_false
      end

      it 'should deregister by passing a Domain instance' do
        registered_domain = Hercule::Document.register_domain( @domain_id )
        registered_domain.should be_a( Hercule::Document::Domain )
        
        Hercule::Document.deregister_domain( registered_domain )
        no_domain = Hercule::Document.find_domain( @domain_id )
        no_domain.should be_false
      end
    end

    context 'initialization' do
      it 'should accept features as a string' do
        new_doc = Hercule::Document.new( @feature_string )
        new_doc.should be_a( Hercule::Document )
        new_doc.feature_list.should == @feature_list_result
      end
      
      it 'should accept features as an array of strings' do
        new_doc = Hercule::Document.new( @feature_array )
        new_doc.should be_a( Hercule::Document )
        new_doc.feature_list.should == @feature_list_result
      end
      
      it 'should raise an exception if invalid features are passed' do
        [nil, 123, {}, [1,'2',3,'4'], :feature_symbol].each do |invalid_features|
          expect{Hercule::Document.new( invalid_features )}.to raise_error(ArgumentError)
        end
      end

      context 'options' do
        it 'should set the label' do
          new_doc = Hercule::Document.new( @feature_string, :label => @label )
          new_doc.label.should == :test_label
        end

        it 'should specify the id of the associated domain' do
          new_doc = Hercule::Document.new( @feature_string, :domain_id => @domain_id )
          new_doc.current_domain.id.should == @domain_id
        end

        it 'should set the document id' do
          new_doc = Hercule::Document.new( @feature_string, :id => @id )
          new_doc.id.should == @id
        end
        
        it 'should set the metadata' do
          new_doc = Hercule::Document.new( @feature_string, :metadata => @metadata )
          new_doc.metadata = @metadata
        end
      end

      it 'should register the specified the domain' do
        new_doc = Hercule::Document.new( @feature_string, :domain_id => @domain_id )
        registered_domain = Hercule::Document.find_domain( @domain_id )
        registered_domain.should == new_doc.current_domain
      end

      context 'document caching' do
        it 'should occur IFF the current domain is not locked and a label is specified' do
          domain = Hercule::Document.register_domain( @domain_id )

          # Label and domain are specified, domain is unlocked, so doc
          # should be cached
          cached_doc_1 = Hercule::Document.new( @feature_string,
                                                :domain_id => @domain_id,
                                                :label => @label )

          domain.cache.should have_key( cached_doc_1.id )
          
          # Label is not specified, so doc should not be cached
          no_label_doc = Hercule::Document.new( @feature_string,
                                                :domain_id => @domain_id )

          domain.cache.should_not have_key( no_label_doc.id )

          # Label is specified but domain is locked, so doc should not
          # be cached
          domain.lock
          locked_domain_doc = Hercule::Document.new( @feature_string,
                                                     :domain_id => @domain_id,
                                                     :label => @label )

          domain.cache.should_not have_key( locked_domain_doc.id )
        end
      end

      it 'should trigger a rebuild of the domain feature dictionary if the current document is not locked' do
        current_dict = @doc.current_domain.dictionary.dup
        Hercule::Document.new( 'A new string to parse into the feature dictionary',
                               :label => @label )
        
        current_dict.should_not == @doc.current_domain.dictionary
        current_dict = @doc.current_domain.dictionary.dup

        @doc.current_domain.lock

        Hercule::Document.new( 'This should not parse into the feature dictionary because the domain is locked',
                               :label => @label )
        current_dict.should == @doc.current_domain.dictionary
      end
      
      it 'should calculate the feature vector' do
        new_doc = Hercule::Document.new( @feature_string )
        new_doc.feature_vector.should == @feature_vector
      end
    end

    context 'instance methods' do
      context 'with public access' do
        it 'should return the current domain' do
          @doc.current_domain.should be_a( Hercule::Document::Domain )
        end

        it "should return the current domain's feature dictionary" do
          @doc.feature_dictionary.should == @doc.current_domain.dictionary
        end
      end
    end
    
    after(:each) do
      Hercule::Document.deregister_domain( @domain_id )
      Hercule::Document.deregister_domain( Hercule::Document::DEFAULT_DOMAIN_ID )
    end
  end
end
