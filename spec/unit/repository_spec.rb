require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

class Vegetable
  include LazyMapper::Resource

  property :id, Integer, :key => true
  property :name, String
end

class Fruit
  include LazyMapper::Resource

  property :id, Integer, :key => true
  property :name, String
end

class Grain
  include LazyMapper::Resource

  property :id, Integer, :key => true
  property :name, String
end

describe LazyMapper::Repository do
  before do
    @adapter       = stub('adapter')
    @identity_map  = stub('identity map', :[]= => nil)
    @identity_maps = stub('identity maps', :[] => @identity_map)

    @repository = repository(:default)
    @repository.stub(:adapter).and_return(@adapter)

    # TODO: stub out other external dependencies in repository
  end

  it 'should provide .storage_exists?' do
    @repository.should respond_to(:storage_exists?)
  end

  it '.storage_exists? should whether or not the storage exists' do
    @adapter.should_receive(:storage_exists?).with(:vegetable).and_return(true)

    @repository.storage_exists?(:vegetable).should == true
  end

  it "should provide persistance methods" do
    @repository.should respond_to(:get)
    @repository.should respond_to(:first)
    @repository.should respond_to(:all)
    @repository.should respond_to(:save)
    @repository.should respond_to(:destroy)
  end

  describe '#save' do
    describe 'with a new resource' do
      it 'should create when dirty' do
        resource = Vegetable.new({:id => 1, :name => 'Potato'})

        resource.should be_dirty
        resource.should be_new_record

        @adapter.stub(:create).with(@repository, resource).and_return(resource)

        @repository.save(resource)
      end

      it 'should create when non-dirty, and it has a serial key' do
        resource = Vegetable.new

        resource.should_not be_dirty
        resource.should be_new_record
        resource.class.key.any? { |p| p.serial? }.should be_true

        @adapter.stub(:create).with(@repository, resource).and_return(resource)

        @repository.save(resource).should be_true
      end
    end

    describe 'with an existing resource' do
      it 'should update when dirty' do
        resource = Vegetable.new(:name => 'Potato')
        resource.instance_variable_set('@new_record', false)

        resource.should be_dirty
        resource.should_not be_new_record

        @adapter.stub(:update).with(@repository, resource).and_return(resource)

        @repository.save(resource)
      end

      it 'should not update when non-dirty' do
        resource = Vegetable.new
        resource.instance_variable_set('@new_record', false)

        resource.should_not be_dirty
        resource.should_not be_new_record

        @adapter.should_not_receive(:update)

        @repository.save(resource)
      end
    end
  end

  it 'should provide default_name' do
    LazyMapper::Repository.should respond_to(:default_name)
  end

  it 'should return :default for default_name' do
    LazyMapper::Repository.default_name.should == :default
  end

  describe "#auto_migrate!" do
    it "should call LazyMapper::AutoMigrator.auto_migrate with itself as the repository argument" do
      LazyMapper::AutoMigrator.stub(:auto_migrate).with(@repository.name)

      @repository.auto_migrate!
    end
  end
end
