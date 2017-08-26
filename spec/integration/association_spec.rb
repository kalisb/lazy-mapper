require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
if ADAPTER
  repository(ADAPTER) do
    class Engine < LazyMapper::Model
      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, serial: true
      property :name, String
      has n, :yards
    end

    class Yard < LazyMapper::Model
      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, serial: true
      property :name, String
      property :rating, Integer
      property :type, String
      has 1, :engine
    end

    class Pie < LazyMapper::Model
      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, serial: true
      property :name, String

      has 1, :sky
    end

    class Sky < LazyMapper::Model
      def self.default_repository_name
        ADAPTER
      end

      property :id, Integer, serial: true
      property :name, String

      has 1, :pie
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
          engine.yards << Yard.new(name: "yard nr #{i}")
        end
        engine.save
        expect(engine.yards.size).to eq 4
        4.times do |i|
          expect(engine.yards.any? { |yard| yard.name == "yard nr #{i}" }).to eq true
        end
        engine = Engine.where(name: 'my engine').to_a[0]
        expect(engine.yards.size).to eq 4
        4.times do |i|
          expect(engine.yards.any? { |yard| yard.name == "yard nr #{i}" }).to eq true
        end
      end

      it 'should add default values for relationships that have conditions' do
        engine = Engine.new(name: 'my engine-2')
        engine.yards << Yard.new(name: 'yard 1', rating: 4, type: 'particular' )
        engine.save
        expect(Yard.first(name: 'yard 1').type).to eq 'particular'
        engine.yards << Yard.new(name: 'yard 2', rating: 4, type: 'not particular')
        expect(Yard.first(name: 'yard 2').type).to eq 'not particular'
        engine.yards << Yard.new(name: 'yard 3')
        expect(Yard.first(name: 'yard 3').rating).to eq nil
      end
    end
    describe 'one to one associations' do
      before do
        Sky.create_table(ADAPTER)
        Pie.create_table(ADAPTER)

        pie1 = Pie.create(name: 'pie1')
        sky1 = Sky.create(name: 'sky1')
        sky1.pie = pie1
      end

      it '#has 1' do
        s = Sky.new
        expect(s).to respond_to(:pie)
        expect(s).to respond_to(:pie=)
      end

      it 'should load the associated instance' do
        sky1 = Sky.first(name: 'sky1')
        pie1 = Pie.first(name: 'pie1')

        expect(sky1.pie).to eq pie1
      end
    end
  end
end
