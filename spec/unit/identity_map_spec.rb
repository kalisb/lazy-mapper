require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "LazyMapper::IdentityMap" do
  before(:all) do
    class Cow
      include LazyMapper::Resource
      property :id, Integer, :key => true
      property :name, String
    end

    class Chicken
      include LazyMapper::Resource
      property :name, String
    end

    class Pig
      include LazyMapper::Resource
      property :id, Integer, :key => true
      property :composite, Integer, :key => true
      property :name, String
    end
  end

  it "should use a second level cache if created with on"

  it "should return nil on #get when it does not find the requested instance" do
    map = LazyMapper::IdentityMap.new
    expect(map.get([23])).to be_nil
  end

  it "should return an instance on #get when it finds the requested instance" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    map = LazyMapper::IdentityMap.new
    map.set(betsy.key, betsy)
    expect(map.get([23])).to eq betsy
  end

  it "should store an instance on #set" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    map = LazyMapper::IdentityMap.new
    map.set(betsy.key, betsy)
    expect(map.get([23])).to eq betsy
  end

  it "should store instances with composite keys on #set" do
    pig = Pig.new({:id=>1,:composite=>1,:name=> 'Pig'})
    piggy = Pig.new({:id=>1,:composite=>2,:name=>'Piggy'})

    map = LazyMapper::IdentityMap.new
    map.set(pig.key, pig)
    map.set(piggy.key, piggy)

    expect(map.get([1,1])).to eq pig
    expect(map.get([1,2])).to eq piggy
  end

  it "should remove an instance on #delete" do
    betsy = Cow.new({:id=>23,:name=>'Betsy'})
    map = LazyMapper::IdentityMap.new
    map.set(betsy.key, betsy)
    map.delete([23])
    expect(map.get([23])).to be_nil
  end
end

describe "Second Level Caching" do

  before :all do
    @mock_class = Class.new do
      def get(key);           raise NotImplementedError end
      def set(key, instance); raise NotImplementedError end
      def delete(key);        raise NotImplementedError end
    end
  end

  it 'should expose a standard API' do
    cache = @mock_class.new
    expect(cache).to respond_to(:get)
    expect(cache).to respond_to(:set)
    expect(cache).to respond_to(:delete)
  end

  it 'should provide values when the first level cache entry is empty' do
    cache = @mock_class.new
    key   = %w[ test ]

    allow(cache).to receive(:get).with(key).and_return('resource')

    map = LazyMapper::IdentityMap.new(cache)
    expect(map.get(key)).to eq 'resource'
  end

  it 'should be set when the first level cache entry is set' do
    cache = @mock_class.new
    betsy = Cow.new(:id => 23, :name => 'Betsy')

    allow(cache).to receive(:set).with(betsy.key, betsy).and_return(betsy)

    map = LazyMapper::IdentityMap.new(cache)
    expect(map.set(betsy.key, betsy)).to eq betsy
  end

  it 'should be deleted when the first level cache entry is deleted' do
    cache = @mock_class.new
    betsy = Cow.new(:id => 23, :name => 'Betsy')

    allow(cache).to receive(:set)
    allow(cache).to receive(:delete).with(betsy.key).and_return(betsy)

    map = LazyMapper::IdentityMap.new(cache)
    expect(map.set(betsy.key, betsy)).to eq betsy
    expect(map.delete(betsy.key)).to eq betsy
  end
end
