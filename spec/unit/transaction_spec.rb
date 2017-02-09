require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe LazyMapper::Transaction do

  before :all do
    class Smurf
      include LazyMapper::Resource
      property :id, Integer, :key => true
    end
  end

  before :each do
    @adapter = double("adapter", :name => 'mock_adapter')
    @repository = double("repository")
    @repository_adapter = double("repository adapter", :name => 'mock_repository_adapter')
    @resource = Smurf.new
    @transaction_primitive = double("transaction primitive")
    @repository_transaction_primitive = double("repository transaction primitive")
    @array = [@adapter, @repository]

    allow(@adapter).to receive(:is_a?).with(Array).and_return(false)
    allow(@adapter).to receive(:is_a?).with(LazyMapper::Adapters::AbstractAdapter).and_return(true)
    allow(@adapter).to receive(:transaction_primitive).and_return(@transaction_primitive)
    allow(@repository).to receive(:is_a?).with(Array).and_return(false)
    allow(@repository).to receive(:is_a?).with(LazyMapper::Adapters::AbstractAdapter).and_return(false)
    allow(@repository).to receive(:is_a?).with(LazyMapper::Repository).and_return(true)
    allow(@repository).to receive(:adapter).and_return(@repository_adapter)
    allow(@repository_adapter).to receive(:is_a?).with(Array).and_return(false)
    allow(@repository_adapter).to receive(:is_a?).with(LazyMapper::Adapters::AbstractAdapter).and_return(true)
    allow(@repository_adapter).to receive(:transaction_primitive).and_return(@repository_transaction_primitive)
    allow(@transaction_primitive).to receive(:respond_to?).with(:close).and_return(true)
    allow(@transaction_primitive).to receive(:respond_to?).with(:begin).and_return(true)
    allow(@transaction_primitive).to receive(:respond_to?).with(:prepare).and_return(true)
    allow(@transaction_primitive).to receive(:respond_to?).with(:rollback).and_return(true)
    allow(@transaction_primitive).to receive(:respond_to?).with(:rollback_prepared).and_return(true)
    allow(@transaction_primitive).to receive(:respond_to?).with(:commit).and_return(true)
    allow(@repository_transaction_primitive).to receive(:respond_to?).with(:close).and_return(true)
    allow(@repository_transaction_primitive).to receive(:respond_to?).with(:begin).and_return(true)
    allow(@repository_transaction_primitive).to receive(:respond_to?).with(:prepare).and_return(true)
    allow(@repository_transaction_primitive).to receive(:respond_to?).with(:rollback).and_return(true)
    allow(@repository_transaction_primitive).to receive(:respond_to?).with(:rollback_prepared).and_return(true)
    allow(@repository_transaction_primitive).to receive(:respond_to?).with(:commit).and_return(true)
  end

  it "should be able to initialize with an Array" do
    LazyMapper::Transaction.new(@array)
  end
  it "should be able to initialize with LazyMapper::Adapters::AbstractAdapters" do
    LazyMapper::Transaction.new(@adapter)
  end
  it "should be able to initialize with LazyMapper::Repositories" do
    LazyMapper::Transaction.new(@repository)
  end
  it "should be able to initialize with LazyMapper::Resource subclasses" do
    LazyMapper::Transaction.new(Smurf)
  end
  it "should be able to initialize with LazyMapper::Resources" do
    LazyMapper::Transaction.new(Smurf.new)
  end
  it "should initialize with no transaction_primitives" do
    expect(LazyMapper::Transaction.new.transaction_primitives.empty?).to be true
  end
  it "should initialize with state :none" do
    expect(LazyMapper::Transaction.new.state).to be :none
  end
  it "should be able receive multiple adapters on creation" do
    LazyMapper::Transaction.new(Smurf, @resource, @adapter, @repository)
  end
  it "should be able to initialize with a block" do
    p = Proc.new do end
    allow(@transaction_primitive).to receive(:begin)
    allow(@transaction_primitive).to receive(:prepare)
    allow(@transaction_primitive).to receive(:commit)
    allow(@adapter).to receive(:push_transaction)
    allow(@adapter).to receive(:pop_transaction)
    allow(@transaction_primitive).to receive(:close)
    LazyMapper::Transaction.new(@adapter, &p)
  end
  it "should accept new adapters after creation" do
    t = LazyMapper::Transaction.new(@adapter, @repository)
    expect(t.adapters).to eq ({@adapter => :none, @repository_adapter => :none})
    t.link(@resource)
    expect(t.adapters).to eq ({@adapter => :none, @repository_adapter => :none, Smurf.repository.adapter => :none})
  end
  it "should not accept new adapters after state is changed" do
    t = LazyMapper::Transaction.new(@adapter, @repository)
    allow(@transaction_primitive).to receive(:begin)
    allow(@repository_transaction_primitive).to receive(:begin)
    t.begin
    expect do t.link(@resource) end.to raise_error(Exception, /Illegal state/)
  end
  describe "#begin" do
    before :each do
      @transaction = LazyMapper::Transaction.new(@adapter, @repository)
    end
    it "should raise error if state is changed" do
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_transaction_primitive).to receive(:begin)
      @transaction.begin
      expect do @transaction.begin end.to raise_error(Exception, /Illegal state/)
    end
    it "should try to connect each adapter (or log fatal error), then begin each adapter (or rollback and close)" do
      allow(@transaction).to receive(:each_adapter).with(:connect_adapter, [:log_fatal_transaction_breakage])
      allow(@transaction).to receive(:each_adapter).with(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      @transaction.begin
    end
    it "should leave with state :begin" do
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_transaction_primitive).to receive(:begin)
      @transaction.begin
      expect(@transaction.state).to eq :begin
    end
  end
  describe "#rollback" do
    before :each do
      @transaction = LazyMapper::Transaction.new(@adapter, @repository)
    end
    it "should raise error if state is :none" do
      expect do @transaction.rollback end.to raise_error(Exception, /Illegal state/)
    end
    it "should raise error if state is :commit" do
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_transaction_primitive).to receive(:begin)
      allow(@transaction_primitive).to receive(:prepare)
      allow(@repository_transaction_primitive).to receive(:prepare)
      allow(@transaction_primitive).to receive(:commit)
      allow(@repository_transaction_primitive).to receive(:commit)
      allow(@transaction_primitive).to receive(:close)
      allow(@repository_transaction_primitive).to receive(:close)
      @transaction.begin
      @transaction.commit
      expect do @transaction.rollback end.to raise_error(Exception, /Illegal state/)
    end
    it "should try to rollback each adapter (or rollback and close), then then close (or log fatal error)" do
      allow(@transaction).to receive(:each_adapter).with(:connect_adapter, [:log_fatal_transaction_breakage])
      allow(@transaction).to receive(:each_adapter).with(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      allow(@transaction).to receive(:each_adapter).with(:rollback_adapter_if_begin, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      allow(@transaction).to receive(:each_adapter).with(:close_adapter_if_open, [:log_fatal_transaction_breakage])
      allow(@transaction).to receive(:each_adapter).with(:rollback_prepared_adapter_if_prepare, [:rollback_prepared_and_close_adapter_if_begin, :close_adapter_if_none])
      @transaction.begin
      @transaction.rollback
    end
    it "should leave with state :rollback" do
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_transaction_primitive).to receive(:begin)
      allow(@transaction_primitive).to receive(:rollback)
      allow(@repository_transaction_primitive).to receive(:rollback)
      allow(@transaction_primitive).to receive(:close)
      allow(@repository_transaction_primitive).to receive(:close)
      @transaction.begin
      @transaction.rollback
      expect(@transaction.state).to eq :rollback
    end
  end
  describe "#commit" do
    describe "without a block" do
      before :each do
        @transaction = LazyMapper::Transaction.new(@adapter, @repository)
      end
      it "should raise error if state is :none" do
        expect do @transaction.commit end.to raise_error(Exception, /Illegal state/)
      end
      it "should raise error if state is :commit" do
        allow(@transaction_primitive).to receive(:begin)
        allow(@repository_transaction_primitive).to receive(:begin)
        allow(@transaction_primitive).to receive(:prepare)
        allow(@repository_transaction_primitive).to receive(:prepare)
        allow(@transaction_primitive).to receive(:commit)
        allow(@repository_transaction_primitive).to receive(:commit)
        allow(@transaction_primitive).to receive(:close)
        allow(@repository_transaction_primitive).to receive(:close)
        @transaction.begin
        @transaction.commit
        expect do @transaction.commit end.to raise_error(Exception, /Illegal state/)
      end
      it "should raise error if state is :rollback" do
        allow(@transaction_primitive).to receive(:begin)
        allow(@repository_transaction_primitive).to receive(:begin)
        allow(@transaction_primitive).to receive(:rollback)
        allow(@repository_transaction_primitive).to receive(:rollback)
        allow(@transaction_primitive).to receive(:close)
        allow(@repository_transaction_primitive).to receive(:close)
        @transaction.begin
        @transaction.rollback
        expect do @transaction.commit end.to raise_error(Exception, /Illegal state/)
      end
      it "should try to prepare each adapter (or rollback and close), then commit each adapter (or log fatal error), then close (or log fatal error)" do
        allow(@transaction).to receive(:each_adapter).with(:connect_adapter, [:log_fatal_transaction_breakage])
        allow(@transaction).to receive(:each_adapter).with(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
        allow(@transaction).to receive(:each_adapter).with(:prepare_adapter, [:rollback_and_close_adapter_if_begin, :rollback_prepared_and_close_adapter_if_prepare])
        allow(@transaction).to receive(:each_adapter).with(:commit_adapter, [:log_fatal_transaction_breakage])
        allow(@transaction).to receive(:each_adapter).with(:close_adapter, [:log_fatal_transaction_breakage])
        @transaction.begin
        @transaction.commit
      end
      it "should leave with state :commit" do
        allow(@transaction_primitive).to receive(:begin)
        allow(@repository_transaction_primitive).to receive(:begin)
        allow(@transaction_primitive).to receive(:prepare)
        allow(@repository_transaction_primitive).to receive(:prepare)
        allow(@transaction_primitive).to receive(:commit)
        allow(@repository_transaction_primitive).to receive(:commit)
        allow(@transaction_primitive).to receive(:close)
        allow(@repository_transaction_primitive).to receive(:close)
        @transaction.begin
        @transaction.commit
        expect(@transaction.state).to eq :commit
      end
    end
    describe "with a block" do
      before :each do
        @transaction = LazyMapper::Transaction.new(@adapter, @repository)
      end
      it "should raise if state is not :none" do
        allow(@transaction_primitive).to receive(:begin)
        allow(@repository_transaction_primitive).to receive(:begin)
        @transaction.begin
        expect do @transaction.commit do end end.to raise_error(Exception, /Illegal state/)
      end
      it "should begin, yield and commit if the block raises no exception" do
        allow(@repository_transaction_primitive).to receive(:begin)
        allow(@repository_transaction_primitive).to receive(:prepare)
        allow(@repository_transaction_primitive).to receive(:commit)
        allow(@repository_transaction_primitive).to receive(:close)
        allow(@transaction_primitive).to receive(:begin)
        allow(@transaction_primitive).to receive(:prepare)
        allow(@transaction_primitive).to receive(:commit)
        allow(@transaction_primitive).to receive(:close)
        p = Proc.new do end
        allow(@transaction).to receive(:within)
        @transaction.commit(&p)
      end
    end
  end
  describe "#within" do
    before :each do
      @transaction = LazyMapper::Transaction.new(@adapter, @repository)
    end
    it "should raise if no block is provided" do
      expect do @transaction.within end.to raise_error(Exception, /No block/)
    end
    it "should raise if state is not :begin" do
      expect do @transaction.within do end end.to raise_error(Exception, /Illegal state/)
    end
    it "should push itself on the per thread transaction context of each adapter and then pop itself out again" do
      allow(@repository_transaction_primitive).to receive(:begin)
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_adapter).to receive(:push_transaction).with(@transaction)
      allow(@adapter).to receive(:push_transaction).with(@transaction)
      allow(@repository_adapter).to receive(:pop_transaction)
      allow(@adapter).to receive(:pop_transaction)
      @transaction.begin
      @transaction.within do end
    end
    it "should push itself on the per thread transaction context of each adapter and then pop itself out again even if an exception was raised" do
      allow(@repository_transaction_primitive).to receive(:begin)
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_adapter).to receive(:push_transaction).with(@transaction)
      allow(@adapter).to receive(:push_transaction).with(@transaction)
      allow(@repository_adapter).to receive(:pop_transaction)
      allow(@adapter).to receive(:pop_transaction)
      @transaction.begin
      expect do @transaction.within do raise "test exception, never mind me" end end.to raise_error(Exception, /test exception, never mind me/)
    end
  end
  describe "#method_missing" do
    before :each do
      @transaction = LazyMapper::Transaction.new(@adapter, @repository)
      allow(@adapter).to receive(:is_a?).with(Regexp).and_return(false)
    end
    it "should delegate calls to [a method we have]_if_[state](adapter) to [a method we have](adapter) if state of adapter is [state]" do
      allow(@transaction).to receive(:state_for).with(@adapter).and_return(:begin)
      allow(@transaction).to receive(:connect_adapter).with(@adapter)
      @transaction.connect_adapter_if_begin(@adapter)
    end
    it "should delegate calls to [a method we have]_unless_[state](adapter) to [a method we have](adapter) if state of adapter is not [state]" do
      allow(@transaction).to receive(:state_for).with(@adapter).and_return(:none)
      allow(@transaction).to receive(:connect_adapter).with(@adapter)
      @transaction.connect_adapter_unless_begin(@adapter)
    end
    it "should not delegate calls whose first argument is not a LazyMapper::Adapters::AbstractAdapter" do
      expect do @transaction.connect_adapter_unless_begin("plur") end.to raise_error
    end
    it "should not delegate calls that do not look like an if or unless followed by a state" do
      expect do @transaction.connect_adapter_unless_hepp(@adapter) end.to raise_error
      expect do @transaction.connect_adapter_when_begin(@adapter) end.to raise_error
    end
    it "should not delegate calls that we can not respond to" do
      expect do @transaction.connect_adapters_unless_begin(@adapter) end.to raise_error
      expect do @transaction.connect_adapters_if_begin(@adapter) end.to raise_error
    end
  end
  it "should be able to produce the connection for an adapter" do
    allow(@transaction_primitive).to receive(:begin)
    allow(@repository_transaction_primitive).to receive(:begin)
    @transaction = LazyMapper::Transaction.new(@adapter, @repository)
    @transaction.begin
    expect(@transaction.primitive_for(@adapter)).to eq @transaction_primitive
  end
  describe "#each_adapter" do
    before :each do
      @transaction = LazyMapper::Transaction.new(@adapter, @repository)
      allow(@adapter).to receive(:is_a?).with(Regexp).and_return(false)
      allow(@repository_adapter).to receive(:is_a?).with(Regexp).and_return(false)
    end
    it "should send the first argument to itself once for each adapter" do
      allow(@transaction).to receive(:plupp).with(@adapter)
      allow(@transaction).to receive(:plupp).with(@repository_adapter)
      @transaction.instance_eval do each_adapter(:plupp, [:plur]) end
    end
  end
  it "should be able to return the state for a given adapter" do
    @transaction = LazyMapper::Transaction.new(@adapter, @repository)
    a1 = @adapter
    a2 = @repository_adapter
    expect(@transaction.instance_eval do state_for(a1) end).to eq :none
    expect(@transaction.instance_eval do state_for(a2) end).to eq :none
    @transaction.instance_eval do @adapters[a1] = :begin end
    expect(@transaction.instance_eval do state_for(a1) end).to eq :begin
    expect(@transaction.instance_eval do state_for(a2) end).to eq :none
  end
  describe "#do_adapter" do
    before :each do
      @transaction = LazyMapper::Transaction.new(@adapter, @repository)
      allow(@adapter).to receive(:is_a?).with(Regexp).and_return(false)
    end
    it "should raise if there is no connection for the adapter" do
      a1 = @adapter
      expect do @transaction.instance_eval do do_adapter(a1, :ping, :pong) end end.to raise_error(Exception, /No primitive/)
    end
    it "should delegate to the adapter if the connection exists and we have the right state" do
      allow(@transaction_primitive).to receive(:begin)
      allow(@repository_transaction_primitive).to receive(:begin)
      @transaction.begin
      a1 = @adapter
      allow(@transaction_primitive).to receive(:ping)
      @transaction.instance_eval do do_adapter(a1, :ping, :begin) end
    end
  end
  describe "#connect_adapter" do
    before :each do
      @other_adapter = double("adapter")
      allow(@other_adapter).to receive(:is_a?).with(Array).and_return(false)
      allow(@other_adapter).to receive(:is_a?).with(LazyMapper::Adapters::AbstractAdapter).and_return(true)
      @transaction = LazyMapper::Transaction.new(@other_adapter)
    end
    it "should be able to connect an adapter" do
      a1 = @other_adapter
      allow(@other_adapter).to receive(:transaction_primitive).and_return(@transaction_primitive)
      @transaction.instance_eval do connect_adapter(a1) end
      expect(@transaction.transaction_primitives[@other_adapter]).to eq @transaction_primitive
    end
  end
  describe "#close adapter" do
    before :each do
      @other_adapter = double("adapter")
      allow(@other_adapter).to receive(:is_a?).with(Array).and_return(false)
      allow(@other_adapter).to receive(:is_a?).with(LazyMapper::Adapters::AbstractAdapter).and_return(true)
      @transaction = LazyMapper::Transaction.new(@other_adapter)
    end
    it "should be able to close the connection of an adapter" do
      a1 = @other_adapter
      allow(@transaction_primitive).to receive(:close)
      allow(@other_adapter).to receive(:transaction_primitive).and_return(@transaction_primitive)
      @transaction.instance_eval do connect_adapter(a1) end
      expect(@transaction.transaction_primitives[@other_adapter]).to eq @transaction_primitive
      @transaction.instance_eval do close_adapter(a1) end
      expect(@transaction.transaction_primitives[@other_adapter]).to eq nil
    end
  end
  describe "the transaction operation methods" do
    before :each do
      @other_adapter = double("adapter")
      allow(@other_adapter).to receive(:is_a?).with(Array).and_return(false)
      allow(@other_adapter).to receive(:is_a?).with(LazyMapper::Adapters::AbstractAdapter).and_return(true)
      allow(@other_adapter).to receive(:is_a?).with(Regexp).and_return(false)
      @transaction = LazyMapper::Transaction.new(@other_adapter)
    end
    it "should only allow adapters in state :none to begin" do
      a1 = @other_adapter
      allow(@transaction).to receive(:do_adapter).with(@other_adapter, :begin, :none)
      @transaction.instance_eval do begin_adapter(a1) end
    end
    it "should only allow adapters in state :begin to prepare" do
      a1 = @other_adapter
      allow(@transaction).to receive(:do_adapter).with(@other_adapter, :prepare, :begin)
      @transaction.instance_eval do prepare_adapter(a1) end
    end
    it "should only allow adapters in state :prepare to commit" do
      a1 = @other_adapter
      allow(@transaction).to receive(:do_adapter).with(@other_adapter, :commit, :prepare)
      @transaction.instance_eval do commit_adapter(a1) end
    end
    it "should only allow adapters in state :begin to rollback" do
      a1 = @other_adapter
      allow(@transaction).to receive(:do_adapter).with(@other_adapter, :rollback, :begin)
      @transaction.instance_eval do rollback_adapter(a1) end
    end
    it "should only allow adapters in state :prepare to rollback_prepared" do
      a1 = @other_adapter
      allow(@transaction).to receive(:do_adapter).with(@other_adapter, :rollback_prepared, :prepare)
      @transaction.instance_eval do rollback_prepared_adapter(a1) end
    end
    it "should do delegate properly for rollback_and_close" do
      a1 = @other_adapter
      allow(@transaction).to receive(:rollback_adapter).with(@other_adapter)
      allow(@transaction).to receive(:close_adapter).with(@other_adapter)
      @transaction.instance_eval do rollback_and_close_adapter(a1) end
    end
    it "should do delegate properly for rollback_prepared_and_close" do
      a1 = @other_adapter
      allow(@transaction).to receive(:rollback_prepared_adapter).with(@other_adapter)
      allow(@transaction).to receive(:close_adapter).with(@other_adapter)
      @transaction.instance_eval do rollback_prepared_and_close_adapter(a1) end
    end
  end
end
