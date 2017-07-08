require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_SQLITE3
  describe LazyMapper::Adapters::Sqlite3Adapter do
    before :all do
      @adapter = repository(:sqlite3).adapter
    end

    describe "auto migrating" do
      before :all do
        class Sputnik
          include LazyMapper::Resource

          property :id, Integer#, :key => true
          #property :name, String
        end
      end

      it "#upgrade_model should work" do
        @adapter.destroy_model_storage(nil, Sputnik)
        expect(@adapter.storage_exists?("sputniks")).to be false
        Sputnik.auto_migrate!(:sqlite3)
        expect(@adapter.storage_exists?("sputniks")).to be true
        @adapter.field_exists?("sputniks", "new_prop").should == false
        Sputnik.property :new_prop, Integer
        Sputnik.auto_upgrade!(:sqlite3)
        @adapter.field_exists?("sputniks", "new_prop").should == true
      end
    end
  end
end
