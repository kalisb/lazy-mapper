require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_SQLITE3
  describe LazyMapper::Adapters::Sqlite3Adapter do
    before :all do
      @adapter = repository(:sqlite3).adapter
      class SSputnik < LazyMapper::Model
        property :id, Integer, key: true
        property :name, String
      end
    end

    describe "auto migrating" do
      it "#upgrade_model should work" do
        @adapter.destroy_model_storage(repository(:sqlite3), SSputnik)
        expect(@adapter.storage_exists?("s_sputniks")).to be false
        SSputnik.create_table(:sqlite3)
        expect(@adapter.storage_exists?("s_sputniks")).to be true
        expect(@adapter.field_exists?("s_sputniks", "new_prop")).to be false
        SSputnik.property :new_prop, Integer
        SSputnik.update_table(:sqlite3)
        expect(@adapter.field_exists?("s_sputniks", "new_prop")).to be true
      end
    end
    describe "querying metadata" do
      before do
        SSputnik.create_table(:sqlite3)
      end

      it "#storage_exists? should return true for tables that exist" do
        expect(@adapter.storage_exists?("s_sputniks")).to be true
      end

      it "#storage_exists? should return false for tables that don't exist" do
        expect(@adapter.storage_exists?("space turds")).to be false
      end

      it "#field_exists? should return true for columns that exist" do
        expect(@adapter.field_exists?("s_sputniks", "name")).to be true
      end

      it "#storage_exists? should return false for tables that don't exist" do
        expect(@adapter.field_exists?("s_sputniks", "plur")).to be false
      end
    end
  end
end
