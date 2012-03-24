require 'spec_helper'

describe Hercule::Classifier do
  include_context 'delegate_interface'
  
  before(:each) do
    @valid_engines = [:lsvm, :custom]
  end

  context 'initialization' do
    it 'should initialize with a valid engine specified' do
      @valid_engines.each do |valid_engine|
        classifier = Hercule::Classifier.new( valid_engine => true )
        classifier.should be_a( Hercule::Classifier )
        classifier.engine.should_not be_nil
      end
    end

    it 'should raise an exception if a valid engine is not specified' do
      expect{ Hercule::Classifier.new }.to raise_error(ArgumentError)
      expect{ Hercule::Classifier.new( :invalid_engine_type => true ) }.to raise_error(ArgumentError)
    end
  end

  it 'should respond to the delegated methods' do
    # delegated_methods defined in delegate_interface shared context
    @delegated_methods.each do |delegated_method|
      Hercule::Classifier.instance_methods.should include( delegated_method )
    end
  end
end
