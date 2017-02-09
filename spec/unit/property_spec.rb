require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe LazyMapper::Property do

  before(:all) do
    class Zoo
      include LazyMapper::Resource
    end

    class Tomato
      include LazyMapper::Resource
    end
  end

  it "should evaluate two similar properties as equal" do
    p1 = LazyMapper::Property.new(Zoo, :name, String)
    p2 = LazyMapper::Property.new(Zoo, :name, String)
    p3 = LazyMapper::Property.new(Zoo, :title, String)
    expect(p1.eql?(p2)).to be true
    expect(p1.hash).to eq p2.hash
    expect(p1.eql?(p3)).to be false
    expect(p1.hash).not_to be p3.hash
  end

  it "should create a String property" do
    property = LazyMapper::Property.new(Zoo, :name, String)
    expect(property.primitive).to be String
  end

  it "should determine its name"  do
    expect(LazyMapper::Property.new(Tomato,:botanical_name,String,{}).name).to eq :botanical_name
  end

  it "should determine whether it is a key" do
    expect(LazyMapper::Property.new(Tomato,:id,Integer,{:key => true}).key?).to be true
    expect(LazyMapper::Property.new(Tomato,:botanical_name,String,{}).key?).to be false
  end

  it "should return an instance variable name" do
   expect(LazyMapper::Property.new(Tomato, :flavor, String, {}).instance_variable_name).to eq '@flavor'
   expect(LazyMapper::Property.new(Tomato, :ripe, TrueClass, {}).instance_variable_name).to eq '@ripe' #not @ripe?
  end

  it "should append ? to TrueClass property reader methods" do
    class Potato
      include LazyMapper::Resource
      property :id, Integer, :key => true
      property :fresh, TrueClass
      property :public, TrueClass
    end

    expect(Potato.new()).to respond_to(:fresh)
    expect(Potato.new()).to respond_to(:fresh?)

    expect(Potato.new(:fresh => true)).to be_fresh

    expect(Potato.new()).to respond_to(:public)
    expect(Potato.new()).to respond_to(:public?)
  end

  it "should raise an ArgumentError when created with an invalid option" do
    expect {
      LazyMapper::Property.new(Tomato,:botanical_name,String,{:foo=>:bar})
    }.to raise_error(ArgumentError)
  end

  it 'should return the attribute value from a given instance' do
    class Tomato
      include LazyMapper::Resource
      property :id, Integer, :key => true
    end

    tomato = Tomato.new(:id => 1)
    expect(tomato.class.properties(:default)[:id].get(tomato)).to eq 1
  end

  it 'should set the attribute value in a given instance' do
    tomato = Tomato.new
    tomato.class.properties(:default)[:id].set(tomato, 2)
    expect(tomato.id).to eq 2
  end

  it 'should provide #typecast' do
    expect(LazyMapper::Property.new(Zoo, :name, String)).to respond_to(:typecast)
  end
end
