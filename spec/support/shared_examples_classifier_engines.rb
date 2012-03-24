shared_examples 'classifier engine' do |classifier_init_options|
  include_context 'delegate_interface'

  let( :classifer_engine ) do
    if classifier_init_options
      described_class.new( classifier_init_options )
    else
      described_class.new
    end
  end

  context 'where the delegate target' do
    it 'should respond to the methods delegated by the classifier proxy' do
      @delegated_methods.each do |delegated_method|
        classifer_engine.should respond_to( delegated_method )
      end
    end
  end
end
