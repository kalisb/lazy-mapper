require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_MYSQL
  describe LazyMapper::Adapters::MysqlAdapter do
    before :all do
      @adapter = repository(:mysql).adapter
    end

    before :all do
      class Sputnik
        include LazyMapper::Resource

        property :id, Integer, :key => true
        property :name, String
      end
    end

    describe "querying metadata" do
      it "#storage_exists? should return true for tables that exist" do
        @adapter.storage_exists?("sputniks").should == true
      end

      it "#storage_exists? should return false for tables that don't exist" do
        @adapter.storage_exists?("space turds").should == false
      end

      it "#field_exists? should return true for columns that exist" do
        @adapter.field_exists?("sputniks", "name").should == true
      end

      it "#storage_exists? should return false for tables that don't exist" do
        @adapter.field_exists?("sputniks", "plur").should == false
      end
    end
  end
end
