shared_context 'delegate_interface' do
  before(:each) do
    @delegated_methods = [:train, :trained?, :classify,
                          :persist, :persist!, :load, :load!]
  end
end
