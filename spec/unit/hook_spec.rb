require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "LazyMapper::Hook" do
  before(:each) do
    @class = Class.new do
      include LazyMapper::Resource

      property :id, Integer, :key => true

      def a_method
      end

      def self.a_class_method
      end
    end
  end

  it 'should generate the correct argument signature' do
    @class.class_eval do
      def some_method(a, b, c)
        [a, b, c]
      end

      def yet_another(a, *heh)p
        [a, *heh]
      end
    end

    expect(@class.args_for(@class.instance_method(:a_method))).to eq ""
    expect(@class.args_for(@class.instance_method(:some_method))).to eq "_1, _2, _3"
    expect(@class.args_for(@class.instance_method(:yet_another))).to eq "_1, *args"
  end

  it 'should install the block under the appropriate hook' do
    @class.class_eval do
      def a_hook
      end
    end
    @class.before :a_hook, &c = lambda { 1 }

    expect(@class.hooks).to have_key(:a_hook)
  end

  it 'should run an advice block for class methods' do
    @class.before_class_method :a_class_method do
      hi_dad!
    end

    allow(@class).to receive(:hi_dad!)

    @class.a_class_method
  end

  it 'should run an advice block for class methods when the class is inherited' do
    @inherited_class = Class.new(@class)

    @class.before_class_method :a_class_method do
      hi_dad!
    end

    allow(@inherited_class).to receive(:hi_dad!)

    @inherited_class.a_class_method
  end


  it 'should run an advice block' do
    @class.before :a_method do
      hi_mom!
    end

    inst = @class.new
    allow(inst).to receive(:hi_mom!)

    inst.a_method
  end

  it 'should run an advice block when the class is inherited' do
    @inherited_class = Class.new(@class)

    @class.before :a_method do
      hi_dad!
    end

    inst = @inherited_class.new
    allow(inst).to receive(:hi_dad!)

    inst.a_method
  end

  it 'should run an advice method' do
    @class.class_eval do
      def hook
      end

      def before_method()
        hi_mom!
      end

      before :hook, :before_method
    end

    inst = @class.new
    allow(inst).to receive(:hi_mom!)

    inst.hook
  end

  describe "using before hook" do

    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      allow(@class).to receive(:install_hook).with(:before, :a_method, :a_hook, :instance)

      @class.before :a_method, :a_hook
    end

    it 'should run the advice before the advised class method' do
      tester = double("tester")
      allow(tester).to receive(:one).and_return(:one)
      allow(tester).to receive(:two).and_return(:two)

      class << @class
        self
      end.instance_eval do
        define_method :hook do
          tester.two
        end
        define_method :one do
          tester.one
        end
      end
      @class.before_class_method :hook, :one

      @class.hook
    end

    it 'should run the advice before the advised method' do
      tester = double("tester")
      allow(tester).to receive(:one).and_return(:one)
      allow(tester).to receive(:two).and_return(:two)

      @class.send(:define_method, :a_method) do
        tester.two
      end

      @class.before :a_method do
        tester.one
      end

      @class.new.a_method
    end

    it 'should execute all class method advices once' do
      tester = double("tester")
      allow(tester).to receive(:before1)
      allow(tester).to receive(:before2)
      @class.class_eval do
        def self.hook
        end
      end
      @class.before_class_method :hook do
        tester.before1
      end
      @class.before_class_method :hook do
        tester.before2
      end

      @class.hook
    end

    it 'should execute all advices once' do
      tester = double("tester")
      allow(tester).to receive(:before1)
      allow(tester).to receive(:before2)

      @class.before :a_method do
        tester.before1
      end

      @class.before :a_method do
        tester.before2
      end

      @class.new.a_method
    end
  end

  describe 'using after hook' do

    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      allow(@class).to receive(:install_hook).with(:after, :a_method, :a_hook, :instance)

      @class.after :a_method, :a_hook
    end

    it 'should run the advice after the advised class method' do
      tester = double("tester")
      allow(tester).to receive(:one).and_return(:one)
      allow(tester).to receive(:two).and_return(:two)
      allow(tester).to receive(:three).and_return(:three)

      @class.after_class_method :a_class_method do
        tester.one
      end
      @class.after_class_method :a_class_method do
        tester.two
      end
      @class.after_class_method :a_class_method do
        tester.three
      end

      @class.a_class_method
    end

    it 'should run the advice after the advised method' do
      tester = double("tester")
      allow(tester).to receive(:one).and_return(:one)
      allow(tester).to receive(:two).and_return(:two)
      allow(tester).to receive(:three).and_return(:three)

      @class.send(:define_method, :a_method) do
        tester.one
      end

      @class.after :a_method do
        tester.two
      end

      @class.after :a_method do
        tester.three
      end

      @class.new.a_method
    end

    it 'should execute all class method advices once' do
      tester = double("tester")
      allow(tester).to receive(:after1)
      allow(tester).to receive(:after2)

      @class.after_class_method :a_class_method do
        tester.after1
      end
      @class.after_class_method :a_class_method do
        tester.after2
      end
      @class.a_class_method
    end

    it 'should execute all advices once' do
      tester = double("tester")
      allow(tester).to receive(:after1)
      allow(tester).to receive(:after2)

      @class.after :a_method do
        tester.after1
      end

      @class.after :a_method do
        tester.after2
      end

      @class.new.a_method
    end

    it "the advised method should still return its normal value" do
      @class.class_eval do
        def returner
          1
        end

        after :returner do
          2
        end
      end

      expect(@class.new.returner).to eq 1
    end
  end

  it 'should allow the use of before and after together on class methods' do
    tester = double("tester")
    allow(tester).to receive(:before).and_return(:one)
    allow(tester).to receive(:method).and_return(:one)
    allow(tester).to receive(:after).and_return(:one)

    class << @class
      self
    end.instance_eval do
      define_method :hook do
        tester.method
      end
    end

    @class.before_class_method :hook do
      tester.before
    end

    @class.after_class_method :hook do
      tester.after
    end

    @class.hook
  end

  it 'should allow the use of before and after together' do
    tester = double("tester")
    allow(tester).to receive(:before).and_return(:one)
    allow(tester).to receive(:method).and_return(:one)
    allow(tester).to receive(:after).and_return(:one)

    @class.class_eval do
      define_method :a_method do
        tester.method
      end

      before :a_method do
        tester.before
      end

      after :a_method do
        tester.after
      end
    end

    @class.new.a_method
  end

  it "should allow advising methods ending in ? or !" do
    tester = double("tester")
    allow(tester).to receive(:before).and_return(:one)
    allow(tester).to receive(:method!).and_return(:one)
    allow(tester).to receive(:method?).and_return(:one)
    allow(tester).to receive(:after).and_return(:one)

    @class.class_eval do
      define_method :a_method! do
        tester.method!
      end

      define_method :a_method? do
        tester.method?
      end

      before :a_method! do
        tester.before
      end

      after :a_method? do
        tester.after
      end
    end

    @class.new.a_method!
    @class.new.a_method?
  end

  it "should allow advising methods ending in ?, ! or = when passing methods as advices" do
    tester = double("tester")
    allow(tester).to receive(:before_bang).and_return(:one)
    allow(tester).to receive(:method!).and_return(:one)
    allow(tester).to receive(:before_eq).and_return(:one)
    allow(tester).to receive(:method_eq).and_return(:one)
    allow(tester).to receive(:method?).and_return(:one)
    allow(tester).to receive(:after).and_return(:one)

    @class.class_eval do
      define_method :a_method! do
        tester.method!
      end

      define_method :a_method? do
        tester.method?
      end

      define_method :a_method= do |value|
        tester.method_eq
      end

      define_method :before_a_method_bang do
        tester.before_bang
      end

      before :a_method!, :before_a_method_bang

      before :a_method=, :before_a_method_eq

      define_method :after_a_method_question do
        tester.after
      end

      after :a_method?, :after_a_method_question
    end

    @class.new.a_method!
    @class.new.a_method?
  end

  it "should complain when only one argument is passed for class methods" do
    expect do
      @class.before_class_method :plur
    end.to raise_error(ArgumentError)
  end

  it "should complain when target_method is not a symbol for class methods" do
    expect do
      @class.before_class_method "hepp", :plur
    end.to raise_error(ArgumentError)
  end

  it "should complain when method_sym is not a symbol" do
    expect do
      @class.before_class_method :hepp, "plur"
    end.to raise_error(ArgumentError)
  end

  it "should complain when only one argument is passed" do
    expect do
      @class.class_eval do
        before :a_method
        after :a_method
      end
    end.to raise_error(ArgumentError)
  end

  it "should complain when target_method is not a symbol" do
    expect do
      @class.class_eval do
        before "target", :something
      end
    end.to raise_error(ArgumentError)
  end

  it "should complain when method_sym is not a symbol" do
    expect do
      @class.class_eval do
        before :target, "something"
      end
    end.to raise_error(ArgumentError)
  end
end
