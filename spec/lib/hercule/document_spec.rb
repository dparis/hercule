require 'spec_helper'

describe 'Hercule' do
  context '::Document' do
    context 'class constants' do
      it 'should define a default domain id' do
        Hercule::Document.const_defined?( :DEFAULT_DOMAIN_ID ).should be_true
      end
    end

    context 'attributes' do
      it 'should allow only reading of feature vector'
      it 'should allow only reading of feature list'
      it 'should allow only reading of document id'

      it 'should provide access to label'
      it 'should provide access to metadata'
    end

    context 'registered domains' do
      it 'should be searchable by domain id'
      it 'should allow new domains to be registered by passing a Domain instance'
      it 'should allow new domains to be registered by passing a domain id'
    end

    context 'initialization' do
      it 'should accept features as a string'
      it 'should accept features as an array of strings'
      it 'should raise an exception if no valid features are passed'

      context 'options' do
        it 'should set the label'
        it 'should set the domain id'
        it 'should set the document id'
        it 'should set the metadata'
      end

      it 'should register the specified the domain'

      context 'document caching' do
        it 'should occur IFF the current domain is not locked and a label is specified'
      end

      context '
    end
  end
end
