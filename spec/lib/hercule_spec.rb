require 'spec_helper'

describe "Hercule" do
  context 'module namespace' do
    it 'should provide Preprocessor' do
      Hercule.const_defined?( :Preprocessor ).should be_true
    end

    it 'should provide Document' do
      Hercule.const_defined?( :Document ).should be_true
    end

    it 'should provide Classifier' do
      Hercule.const_defined?( :Preprocessor ).should be_true
    end

    it 'should provide ClassifierEngines' do
      Hercule.const_defined?( :ClassifierEngines ).should be_true
    end

    it 'should not expose Domain' do
      Hercule.const_defined?( :Domain ).should be_false
    end
  end
end
