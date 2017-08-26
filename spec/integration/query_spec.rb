require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
if ADAPTER
  describe LazyMapper::Query, "with #{ADAPTER}" do
    describe 'when ordering' do
      before :all do
        class SailBoat < LazyMapper::Model
          property :id, Integer, serial: true
          property :name, String
          property :port, String
        end
      end

      before do
        SailBoat.create_table(ADAPTER)

        repository(ADAPTER) do
          SailBoat.create(name: 'A', port: 'C')
          SailBoat.create(name: 'B', port: 'B')
          SailBoat.create(name: 'C', port: 'A')
        end
      end

      it "should find by conditions passed" do
        repository(ADAPTER) do
          find = SailBoat.all(id: 1)
          expect(find).not_to be_nil
          expect(find.size).to eq 1

          find = SailBoat.all(:id.not => 1)
          expect(find.size).to eq 2

          find = SailBoat.all(:id.eql => 1)
          expect(find.size).to eq 1

          find = SailBoat.all(:id.gt => 1)
          expect(find.size).to eq 2

          find = SailBoat.all(:id.gte => 1)
          expect(find.size).to eq 3

          find = SailBoat.all(:id.lt => 1)
          expect(find.size).to eq 0

          find = SailBoat.all(:id.lte => 1)
          expect(find.size).to eq 1
        end
      end

      it "should order results" do
        repository(ADAPTER) do
          result = SailBoat.all(order: [LazyMapper::Query::Direction.new(SailBoat.properties[:name], :asc)])
          expect(result[0].id).to eq 1

          result = SailBoat.all(order: [LazyMapper::Query::Direction.new(SailBoat.properties[:port], :asc)])
          expect(result[0].id).to eq 3

          result = SailBoat.all(order: [:name.desc])
          expect(result[0].id).to eq 3
        end
      end

      it "should count results" do
        repository(ADAPTER) do
          result = SailBoat.count
          expect(result[0]).to eq 3

          result = SailBoat.where(:id.gte => 1).limit(2).to_a
          expect(result[0].id).to eq 1
          expect(result.size).to eq 2
        end
      end
    end
  end
end
