require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
if ADAPTER
  describe 'LazyMapper::Model' do
    before :all do
      # A simplistic example, using with an Integer property
      class Dragon < LazyMapper::Model
        def self.default_repository_name
          ADAPTER
        end
        property :id, Integer, serial: true
        property :name, String
        property :toes_on_claw, Integer
      end

      Dragon.create_table

      Dragon.create(name: 'George', toes_on_claw: 3)
      Dragon.create(name: 'Puff', toes_on_claw: 4)
      Dragon.create(name: nil, toes_on_claw: 5)
    end
    describe '.count' do
      it 'should count the results' do
        expect(Dragon.count[0]).to eq 3
        expect(Dragon.count(:toes_on_claw.gt => 3)[0]).to eq 2
      end
    end
    describe '.min' do
      it 'with a property name' do
        expect(Dragon.min(:toes_on_claw)[0]).to eq 3
      end
    end
    describe '.max' do
      it 'should provide the highest value of an Integer property' do
        expect(Dragon.max(:toes_on_claw)[0]).to eq 5
      end
    end
    describe '.avg' do
      it 'should provide the avarage value of an Integer property' do
        expect(Dragon.avg(:toes_on_claw)[0]).to eq 4
      end
    end
    describe '.sum' do
      it 'should provide the sum value of an Integer property' do
        expect(Dragon.sum(:toes_on_claw)[0]).to eq 12
      end
    end
  end
end
