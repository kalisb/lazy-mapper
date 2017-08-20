require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_POSTGRES
  describe LazyMapper::Adapters::PostgresAdapter do
      before :all do
        @adapter = repository(:postgres).adapter
      end

      describe "auto migrating" do
      before :all do
        class Sputnik < LazyMapper::Model

          property :id, Integer, :key => true
          property :name, String
        end
      end

      it "#upgrade_model should work" do
        @adapter.destroy_model_storage(repository(:postgres), Sputnik)
        expect(@adapter.storage_exists?("sputniks")).to be false
        Sputnik.auto_migrate!(:postgres)
        expect(@adapter.storage_exists?("sputniks")).to be true
        expect(@adapter.field_exists?("sputniks", "new_prop")).to be false
        Sputnik.property :new_prop, Integer
        Sputnik.auto_upgrade!(:postgres)
        expect(@adapter.field_exists?("sputniks", "new_prop")).to be true
      end
    end

    describe "querying metadata" do
      before :all do
        class Sputnik
          include LazyMapper::Resource

          property :id, Integer
          property :name, String
        end

        Sputnik.auto_upgrade!(:postgres)
      end

      it "#storage_exists? should return true for tables that exist" do
        expect(@adapter.storage_exists?("sputniks")).to be true
      end

      it "#storage_exists? should return false for tables that don't exist" do
        expect(@adapter.storage_exists?("turds")).to be false
      end

      it "#field_exists? should return true for columns that exist" do
        expect(@adapter.field_exists?("sputniks", "name")).to be true
      end

      it "#field_exists? should return false for columns that don't exist" do
        expect(@adapter.field_exists?("sputniks", "plur")).to be false
      end
    end

  end
end
