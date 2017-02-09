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
    p1.eql?(p2).should == true
    p1.hash.should == p2.hash
    p1.eql?(p3).should == false
    p1.hash.should_not == p3.hash
  end

  it "should create a String property" do
    property = LazyMapper::Property.new(Zoo, :name, String)

    property.primitive.should == String
  end

  it "should determine its name"  do
    LazyMapper::Property.new(Tomato,:botanical_name,String,{}).name.should == :botanical_name
  end

  it "should determine whether it is a key" do
    LazyMapper::Property.new(Tomato,:id,Integer,{:key => true}).key?.should == true
    LazyMapper::Property.new(Tomato,:botanical_name,String,{}).key?.should == false
  end

  it "should return an instance variable name" do
   LazyMapper::Property.new(Tomato, :flavor, String, {}).instance_variable_name.should == '@flavor'
   LazyMapper::Property.new(Tomato, :ripe, TrueClass, {}).instance_variable_name.should == '@ripe' #not @ripe?
  end

  it "should append ? to TrueClass property reader methods" do
    class Potato
      include LazyMapper::Resource
      property :id, Integer, :key => true
      property :fresh, TrueClass
      property :public, TrueClass
    end

    Potato.new().should respond_to(:fresh)
    Potato.new().should respond_to(:fresh?)

    Potato.new(:fresh => true).should be_fresh

    Potato.new().should respond_to(:public)
    Potato.new().should respond_to(:public?)
  end

  it "should raise an ArgumentError when created with an invalid option" do
    lambda{
      LazyMapper::Property.new(Tomato,:botanical_name,String,{:foo=>:bar})
    }.should raise_error(ArgumentError)
  end

  it 'should return the attribute value from a given instance' do
    class Tomato
      include LazyMapper::Resource
      property :id, Integer, :key => true
    end

    tomato = Tomato.new(:id => 1)
    tomato.class.properties(:default)[:id].get(tomato).should == 1
  end

  it 'should set the attribute value in a given instance' do
    tomato = Tomato.new
    tomato.class.properties(:default)[:id].set(tomato, 2)
    tomato.id.should == 2
  end

  it 'should provide #typecast' do
    LazyMapper::Property.new(Zoo, :name, String).should respond_to(:typecast)
  end
end
