require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

class Icon < LazyMapper::Model

      property :id, Integer
      property :name, String
      property :width, Integer, :lazy => true
      property :height, Integer, :lazy => true
end

describe LazyMapper::PropertySet do
  before :each do
    @properties = Icon.properties(:default).dup
  end

  it "should provide defaults" do
   expect(@properties.defaults.size).to eq 2
   expect(@properties.length).to eq 4
  end

  it 'should add a property for lazy loading  to the :default context if a context is not supplied' do
    expect(Icon.properties(:default).lazy_context(:default).length).to eq 2 # text & notes
  end
end
