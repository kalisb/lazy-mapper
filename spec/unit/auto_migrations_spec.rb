require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require LazyMapper.root / 'lib' / 'lazy_mapper' / 'repository'
require LazyMapper.root / 'lib' / 'lazy_mapper' / 'resource'
require LazyMapper.root / 'lib' / 'lazy_mapper' / 'auto_migrations'

describe LazyMapper::AutoMigrations do

  before :all do
    @cow = Class.new do
      include LazyMapper::Resource

      property :name, String, :key => true
      property :age, Integer
    end
  end

  before(:each) do
    LazyMapper::Resource.descendents.clear
  end

  after(:each) do
    LazyMapper::Resource.descendents.clear
  end

  it "should add the #auto_migrate! method on a mixin" do
    @cat = Class.new do
      include LazyMapper::Resource

      property :name, String, :key => true
      property :age, Integer
    end

    expect(@cat).to respond_to(:auto_migrate!)
  end

  it "should add the #auto_upgrade! method on a mixin" do
    @cat = Class.new do
      include LazyMapper::Resource

      property :name, String, :key => true
      property :age, Integer
    end

    expect(@cat).to respond_to(:auto_upgrade!)
  end

  describe "#auto_migrate" do
    before do
      @repository_name = double('repository name')
    end

    it "should call each model's auto_migrate! method" do
      models = [:cat, :dog, :fish, :cow].map {|m| double(m)}

      models.each do |model|
        LazyMapper::Resource.descendents << model
        allow(model).to receive(:auto_migrate!).with(@repository_name)
      end

      LazyMapper::AutoMigrator.auto_migrate(@repository_name)
    end
  end
  describe "#auto_upgrade" do
    before do
      @repository_name = double('repository name')
    end

    it "should call each model's auto_upgrade! method" do
      models = [:cat, :dog, :fish, :cow].map {|m| double(m)}

      models.each do |model|
        LazyMapper::Resource.descendents << model
        allow(model).to receive(:auto_upgrade!).with(@repository_name)
      end

      LazyMapper::AutoMigrator.auto_upgrade(@repository_name)
    end
  end
end
