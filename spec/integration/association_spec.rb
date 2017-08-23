require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
if ADAPTER
  repository(ADAPTER) do
    class Engine < LazyMapper::Model
      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :name, String
      has n, :yards
    end

    class Yard < LazyMapper::Model
      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, :serial => true
      property :name, String
      property :rating, Integer
      property :type, String
    end
  end
  describe "LazyMapper::Associations" do
    describe 'many to one associations' do
      before do
        Engine.create_table(ADAPTER)
        Yard.create_table(ADAPTER)
      end

      it 'should add exactly the parameters' do
        engine = Engine.new(:name => 'my engine')
        4.times do |i|
          engine.yards << Yard.new(:name => "yard nr #{i}")
        end
        engine.save
        expect(engine.yards.size).to eq 4
        4.times do |i|
          expect(engine.yards.any? do |yard|
            yard.name == "yard nr #{i}"
          end).to eq true
        end
        engine = Engine.where(id: engine.id).to_a.get(0)
        expect(engine.yards.size).to eq 4
        4.times do |i|
          expect(engine.yards.any? do |yard|
            yard.name == "yard nr #{i}"
          end).to eq true
        end
      end
    end
  end
end
