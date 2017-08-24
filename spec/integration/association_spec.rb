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
      has 1, :engine
    end
  end
  describe "LazyMapper::Associations" do
    describe 'many to one associations' do
      before do
        Engine.create_table(ADAPTER)
        Yard.create_table(ADAPTER)
      end

      it 'should add exactly the parameters' do
        engine = Engine.new(name: 'my engine')
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
        engine = Engine.where(name: 'my engine').to_a[0]
        puts   engine.to_s
        puts Yard.all
        puts  Engine.all
        expect(engine.yards.size).to eq 4
        #4.times do |i|
        #  expect(engine.yards.any? do |yard|
        #    yard.name == "yard nr #{i}"
        #  end).to eq true
        #end
      end

      it 'should add default values for relationships that have conditions' do
      #  engine = Engine.create(:name => 'my engine-2')
      #  engine.yards << Yard.create(:name => 'yard 1', :rating => 4 )
      #  engine.save
      #  expect(Yard.first(:name => 'yard 1').type).to eq 'particular'
      #  engineyards << Yard.create(:name => 'yard 2', :rating => 4, :type => 'not particular')
      #  expect(Yard.first(:name => 'yard 2').type).to eq 'not particular'
      #  engine.yards << Yard.create(:name => 'yard 3')
      #  expect(Yard.first(:name => 'yard 3').rating).to eq nil
      end
    end
  end
end
