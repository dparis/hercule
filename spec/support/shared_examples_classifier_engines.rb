shared_examples 'classifier_engine' do |classifier_init_options|
  include_context 'delegate_interface'

  let( :classifer_engine ) do
    described_class.new( classifier_init_options )
  end

  describe 'classifer_engine' do
    it 'should respond to the methods delegated by the classifier proxy' do
      @delegated_methods.each do |delegated_method|
        classifer_engine.should respond_to( delegated_method )
      end
    end
  end
end
