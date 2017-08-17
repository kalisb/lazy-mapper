require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "LazyMapper::Associations" do
  before :each do
    @relationship = double(LazyMapper::Associations::Relationship)
    @n = 1.0/0
  end

  describe ".relationships" do
    class B
      include LazyMapper::Resource
    end

    class C
      include LazyMapper::Resource
      has 1, :b
    end

    class D
      include LazyMapper::Resource
      has 1, :b
    end

    class E < D
    end

    class F < D
      has 1, :a
    end

    it "should return the right set of relationships" do
      expect(C.relationships).not_to be_empty
    end
  end

  describe ".has" do

    it "should allow a declaration" do
      expect do
        class Manufacturer
          include LazyMapper::Resource
          has 1, :halo_car
        end
      end.not_to raise_error
    end

    it "should not allow a constraint that is not a Range, Fixnum, Bignum or Infinity" do
      expect do
        class Manufacturer
          include LazyMapper::Resource
          has '1', :halo_car
        end
      end.to raise_error(ArgumentError)
    end

    it "should not allow a constraint where the min is larger than the max" do
      expect do
        class Manufacturer
          has 1..0, :halo_car
        end
      end.to raise_error(ArgumentError)
    end

    it "should not allow overwriting of the auto assigned min/max values with keys" do
      allow(Manufacturer).to receive(:one_to_many).
        with(:vehicles, {:min=>1, :max=>2}).
        and_return(@relationship)
      class Manufacturer
        has 1..2, :vehicles, :min=>5, :max=>10
      end
    end

    describe "one-to-one syntax" do
      it "should create a basic one-to-one association with fixed constraint" do
        allow(Manufacturer).to receive(:one_to_one).
          with(:halo_car, { :min => 1, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 1, :halo_car
        end
      end

      it "should create a basic one-to-one association with min/max constraints" do
        allow(Manufacturer).to receive(:one_to_one).
          with(:halo_car, { :min => 0, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 0..1, :halo_car
        end
      end

      it "should create a one-to-one association with options" do
        allow(Manufacturer).to receive(:one_to_one).
          with(:halo_car, {:class_name => 'Car', :min => 1, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 1, :halo_car,
            :class_name => 'Car'
        end
      end
    end

    describe "one-to-many syntax" do
      it "should create a basic one-to-many association with no constraints" do
        allow(Manufacturer).to receive(:one_to_many).
          with(:vehicles,{}).
          and_return(@relationship)
        class Manufacturer
          has n, :vehicles
        end
      end

      it "should create a one-to-many association with fixed constraint" do
        allow(Manufacturer).to receive(:one_to_many).
          with(:vehicles,{:min=>4, :max=>4}).
          and_return(@relationship)
        class Manufacturer
          has 4, :vehicles
        end
      end

      it "should create a one-to-many association with min/max constraints" do
        allow(Manufacturer).to receive(:one_to_many).
          with(:vehicles,{:min=>2, :max=>4}).
          and_return(@relationship)
        class Manufacturer
          has 2..4, :vehicles
        end
      end

      it "should create a one-to-many association with options" do
        allow(Manufacturer).to receive(:one_to_many).
          with(:vehicles,{:min=>1, :max=>@n, :class_name => 'Car'}).
          and_return(@relationship)
        class Manufacturer
          has 1..n, :vehicles,
            :class_name => 'Car'
        end
      end

      # do not remove or change this spec.
      it "should raise an exception when n..n is used for the cardinality" do
        expect do
          class Manufacturer
            has n..n, :subsidiaries, :class_name => 'Manufacturer'
          end
        end.to raise_error(ArgumentError)
      end
    end
  end
end
