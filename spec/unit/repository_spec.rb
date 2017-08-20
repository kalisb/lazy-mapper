require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

class Vegetable < LazyMapper::Model

  property :id, Integer, :key => true
  property :name, String
end

class Fruit < LazyMapper::Model

  property :id, Integer, :key => true
  property :name, String
end

class Grain < LazyMapper::Model

  property :id, Integer, :key => true
  property :name, String
end

describe LazyMapper::Repository do
  before do
    @adapter       = double('adapter')
    @identity_map  = double('identity map', :[]= => nil)
    @identity_maps = double('identity maps', :[] => @identity_map)

    @repository = repository(:default)
    allow(@repository).to receive(:adapter).and_return(@adapter)
  end

  it 'should provide .storage_exists?' do
    expect(@repository).to respond_to(:storage_exists?)
  end

  it '.storage_exists? should whether or not the storage exists' do
    allow(@adapter).to receive(:storage_exists?).with(:vegetable).and_return(true)

    expect(@repository.storage_exists?(:vegetable)).to be true
  end

  it "should provide persistance methods" do
    expect(@repository).to respond_to(:get)
    expect(@repository).to respond_to(:first)
    expect(@repository).to respond_to(:all)
    expect(@repository).to respond_to(:save)
    expect(@repository).to respond_to(:destroy)
  end

  describe '#save' do
    describe 'with a new resource' do
      it 'should create when dirty' do
        resource = Vegetable.new({:id => 1, :name => 'Potato'})

        expect(resource).to be_dirty
        expect(resource).to be_new_record

        allow(@adapter).to receive(:create).with(@repository, resource).and_return(resource)

        @repository.save(resource)
      end

      it 'should create when non-dirty, and it has a serial key' do
        resource = Vegetable.new

        expect(resource).not_to be_dirty
        expect(resource).to be_new_record

        allow(@adapter).to receive(:create).with(@repository, resource).and_return(resource)

        expect(@repository.save(resource)).to be true
      end
    end

    describe 'with an existing resource' do
      it 'should update when dirty' do
        resource = Vegetable.new(:name => 'Potato')
        resource.instance_variable_set('@new_record', false)

        expect(resource).to be_dirty
        expect(resource).not_to be_new_record

        allow(@adapter).to receive(:update).with(@repository, resource).and_return(resource)

        @repository.save(resource)
      end
    end
  end

  it 'should provide default_name' do
    expect(LazyMapper::Repository).to respond_to(:default_name)
  end

  it 'should return :default for default_name' do
    expect(LazyMapper::Repository.default_name).to eq :default
  end
end
