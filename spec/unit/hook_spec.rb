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

    @class.args_for(@class.instance_method(:a_method)).should == ""
    @class.args_for(@class.instance_method(:some_method)).should == "_1, _2, _3"
    @class.args_for(@class.instance_method(:yet_another)).should == "_1, *args"
  end

  it 'should install the block under the appropriate hook' do
    @class.class_eval do
      def a_hook
      end
    end
    @class.before :a_hook, &c = lambda { 1 }

    @class.hooks.should have_key(:a_hook)
    @class.hooks[:a_hook][:before].should have(1).item
  end

  it 'should run an advice block for class methods' do
    @class.before_class_method :a_class_method do
      hi_dad!
    end

    @class.should_receive(:hi_dad!)

    @class.a_class_method
  end

  it 'should run an advice block for class methods when the class is inherited' do
    @inherited_class = Class.new(@class)

    @class.before_class_method :a_class_method do
      hi_dad!
    end

    @inherited_class.should_receive(:hi_dad!)

    @inherited_class.a_class_method
  end


  it 'should run an advice block' do
    @class.before :a_method do
      hi_mom!
    end

    inst = @class.new
    inst.should_receive(:hi_mom!)

    inst.a_method
  end

  it 'should run an advice block when the class is inherited' do
    @inherited_class = Class.new(@class)

    @class.before :a_method do
      hi_dad!
    end

    inst = @inherited_class.new
    inst.should_receive(:hi_dad!)

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
    inst.should_receive(:hi_mom!)

    inst.hook
  end

  describe "using before hook" do
    it "should install the advice block under the appropriate hook" do
      c = lambda { 1 }

      @class.should_receive(:install_hook).with(:before, :a_method, nil, :instance, &c)

      @class.class_eval do
        before :a_method, &c
      end
    end

    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      @class.should_receive(:install_hook).with(:before, :a_method, :a_hook, :instance)

      @class.before :a_method, :a_hook
    end

    it 'should run the advice before the advised class method' do
      tester = double("tester")
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered

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
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered

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
      tester.should_receive(:before1)
      tester.should_receive(:before2)
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
      tester.should_receive(:before1)
      tester.should_receive(:before2)

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
    it "should install the advice block under the appropriate hook" do
      c = lambda { 1 }
      @class.should_receive(:install_hook).with(:after, :a_method, nil, :instance, &c)

      @class.class_eval do
        after :a_method, &c
      end
    end

    it 'should install the advice method under the appropriate hook' do
      @class.class_eval do
        def a_hook
        end
      end

      @class.should_receive(:install_hook).with(:after, :a_method, :a_hook, :instance)

      @class.after :a_method, :a_hook
    end

    it 'should run the advice after the advised class method' do
      tester = double("tester")
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered
      tester.should_receive(:three).ordered

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
      tester.should_receive(:one).ordered
      tester.should_receive(:two).ordered
      tester.should_receive(:three).ordered

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
      tester.should_receive(:after1)
      tester.should_receive(:after2)

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
      tester.should_receive(:after1)
      tester.should_receive(:after2)

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

      @class.new.returner.should == 1
    end
  end

  it 'should allow the use of before and after together on class methods' do
    tester = double("tester")
    tester.should_receive(:before).ordered.once
    tester.should_receive(:method).ordered.once
    tester.should_receive(:after).ordered.once

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
    tester.should_receive(:before).ordered.once
    tester.should_receive(:method).ordered.once
    tester.should_receive(:after).ordered.once

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
    tester.should_receive(:before).ordered.once
    tester.should_receive(:method!).ordered.once
    tester.should_receive(:method?).ordered.once
    tester.should_receive(:after).ordered.once

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
    tester.should_receive(:before_bang).ordered.once
    tester.should_receive(:method!).ordered.once
    tester.should_receive(:before_eq).ordered.once
    tester.should_receive(:method_eq).ordered.once
    tester.should_receive(:method?).ordered.once
    tester.should_receive(:after).ordered.once

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

      define_method :before_a_method_eq do
        tester.before_eq
      end

      before :a_method=, :before_a_method_eq

      define_method :after_a_method_question do
        tester.after
      end

      after :a_method?, :after_a_method_question
    end

    @class.new.a_method!
    @class.new.a_method = 1
    @class.new.a_method?
  end

  it "should complain when only one argument is passed for class methods" do
    lambda do
      @class.before_class_method :plur
    end.should raise_error(ArgumentError)
  end

  it "should complain when target_method is not a symbol for class methods" do
    lambda do
      @class.before_class_method "hepp", :plur
    end.should raise_error(ArgumentError)
  end

  it "should complain when method_sym is not a symbol" do
    lambda do
      @class.before_class_method :hepp, "plur"
    end.should raise_error(ArgumentError)
  end

  it "should complain when only one argument is passed" do
    lambda do
      @class.class_eval do
        before :a_method
        after :a_method
      end
    end.should raise_error(ArgumentError)
  end

  it "should complain when target_method is not a symbol" do
    lambda do
      @class.class_eval do
        before "target", :something
      end
    end.should raise_error(ArgumentError)
  end

  it "should complain when method_sym is not a symbol" do
    lambda do
      @class.class_eval do
        before :target, "something"
      end
    end.should raise_error(ArgumentError)
  end


  describe 'aborting' do
    class CaptHook
      include LazyMapper::Resource
      property :id, Integer, :key => true

      @@ruler_of_all_neverland = false
      @@clocks_bashed = 0

      def self.ruler_of_all_neverland?
        @@ruler_of_all_neverland
      end

      def self.conquer_neverland
        @@ruler_of_all_neverland = true
      end

      def self.bash_clock
        @@clocks_bashed += 1
      end

      def self.clocks_bashed
        @@clocks_bashed
      end

      def self.walk_the_plank!
        true
      end

      def get_eaten_by_croc
        self.eaten = true
      end

      def throw_halt
        throw :halt
      end
    end


    it "should catch :halt from a before instance hook and abort the advised method" do
      CaptHook.before :get_eaten_by_croc, :throw_halt
      capt_hook = CaptHook.new
      lambda {
        capt_hook.get_eaten_by_croc
        capt_hook.should_not be_eaten
      }.should_not throw_symbol(:halt)
    end

    it "should catch :halt from an after instance hook and cease the advice" do
      CaptHook.after :get_eaten_by_croc, :throw_halt
      capt_hook = CaptHook.new
      lambda {
        capt_hook.get_eaten_by_croc
        capt_hook.should be_eaten
       }.should_not throw_symbol(:halt)
    end

    it "should catch :halt from a before class method hook and abort advised method" do
      CaptHook.before_class_method :conquer_neverland, :throw_halt
      lambda {
        CaptHook.conquer_neverland
        CaptHook.should_not be_ruler_of_all_neverland
      }.should_not throw_symbol(:halt)

    end

    it "should catch :halt from an after class method hook and abort the rest of the advice" do
      CaptHook.after_class_method :bash_clock, :throw_halt
      lambda {
        CaptHook.bash_clock
        CaptHook.clocks_bashed.should == 1
      }.should_not throw_symbol(:halt)

    end

    after do
      # Thus perished James Hook
      CaptHook.walk_the_plank!
    end
  end


end
