require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# rSpec completely FUBARs everything if you give it a Module here.
# So we give it a String of the module name instead.
# DO NOT CHANGE THIS!
describe "LazyMapper::Model" do

  before :all do
    class Planet < LazyMapper::Model

      storage_names[:legacy] = "dying_planets"

      property :id, Integer, key: true
      property :age, Integer
      property :core, String
    end

    class LegacyStar < LazyMapper::Model
      def self.default_repository_name
        :legacy
      end
    end

    class Phone < LazyMapper::Model

      property :name, String, key: true
      property :awesomeness, Integer
    end
  end

  describe "storage names" do
    it "should use its class name by default" do
      expect(Planet.storage_name).to eq "planets"
    end
  end

  it "should return an instance of the created object" do
     expect(Planet.create!(name: 'Venus', age: 1_000_000, core: nil, id: 42)).to be_a_kind_of(Planet)
  end

  it 'should provide persistance methods' do
   planet = Planet.new
   expect(planet).to respond_to(:new_record?)
   expect(planet).to respond_to(:save)
   expect(planet).to respond_to(:destroy)
 end
end
