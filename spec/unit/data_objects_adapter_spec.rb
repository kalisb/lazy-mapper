require 'monitor'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# TODO: make a shared adapter spec for all the DAO objects to adhere to

describe LazyMapper::Adapters::DataObjectsAdapter do
  before :all do
    class Cheese
      include LazyMapper::Resource
      property :id, Integer, :key => true
      property :name, String
      property :color, String
      property :notes, String
    end
  end

  before do
    @uri     = Addressable::URI.parse('mock://localhost')
    @adapter = LazyMapper::Adapters::DataObjectsAdapter.new(:default, @uri)
  end

  describe "#find_by_sql" do

    before do
      class Plupp
        include LazyMapper::Resource
        property :id, Integer, :key => true
        property :name, String
      end
    end

    it "should be added to LazyMapper::Resource::ClassMethods" do
      expect(LazyMapper::Resource::ClassMethods.instance_methods.include?("find_by_sql")).to eq true
      expect(Plupp).to respond_to(:find_by_sql)
    end

    describe "when called" do

      before do
        @reader = double("reader")
        allow(@reader).to receive(:next!).and_return(false)
        allow(@reader).to receive(:close)
        @connection = double("connection")
        allow(@connection).to receive(:close)
        @command = double("command")
        @adapter = Plupp.repository.adapter
        @repository = Plupp.repository
        allow(@repository).to receive(:adapter).and_return(@adapter)
        allow(@adapter).to receive(:create_connection).and_return(@connection)
        allow(@adapter).to receive(:is_a?).with(LazyMapper::Adapters::DataObjectsAdapter).and_return(true)
      end

      it "should accept a single String argument with or without options hash" do
        allow(@connection).to receive(:create_command).twice.with("SELECT * FROM plupps").and_return(@command)
        allow(@command).to receive(:set_types).twice.with([Integer, String])
        allow(@command).to receive(:execute_reader).twice.and_return(@reader)
        allow(Plupp).to receive(:repository).and_return(@repository)
        allow(Plupp).to receive(:repository).with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql("SELECT * FROM plupps").to_a
        Plupp.find_by_sql("SELECT * FROM plupps", :repository => :plupp_repo).to_a
      end

      it "should accept an Array argument with or without options hash" do
        allow(@connection).to receive(:create_command).twice.with("SELECT * FROM plupps WHERE plur = ?").and_return(@command)
        allow(@command).to receive(:set_types).twice.with([Integer, String])
        allow(@command).to receive(:execute_reader).twice.with("my pretty plur").and_return(@reader)
        allow(Plupp).to receive(:repository).and_return(@repository)
        allow(Plupp).to receive(:repository).with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"]).to_a
        Plupp.find_by_sql(["SELECT * FROM plupps WHERE plur = ?", "my pretty plur"], :repository => :plupp_repo).to_a
      end

      it "should accept a Query argument with or without options hash" do
        allow(@connection).to receive(:create_command).twice.with("SELECT \"name\" FROM \"plupps\" WHERE \"name\" = ?").and_return(@command)
        allow(@command).to receive(:set_types).twice.with([Integer, String])
        allow(@command).to receive(:execute_reader).twice.with(Plupp.properties[:name]).and_return(@reader)
        allow(Plupp).to receive(:repository).and_return(@repository)
        allow(Plupp).to receive(:repository).with(:plupp_repo).and_return(@repository)
        Plupp.find_by_sql(LazyMapper::Query.new(@repository, Plupp, "name" => "my pretty plur", :fields => ["name"])).to_a
        Plupp.find_by_sql(LazyMapper::Query.new(@repository, Plupp, "name" => "my pretty plur", :fields => ["name"]), :repository => :plupp_repo).to_a
      end

      it "requires a Repository that is a DataObjectsRepository to work" do
        non_do_adapter = double("non do adapter")
        non_do_repo = double("non do repo")
        allow(non_do_repo).to receive(:adapter).and_return(non_do_adapter)
        allow(Plupp).to receive(:repository).with(:plupp_repo).and_return(non_do_repo)
        expect Proc.new do
          Plupp.find_by_sql(:repository => :plupp_repo)
        end.to raise_error(Exception, /DataObjectsAdapter/)
      end

      it "requires some kind of query to work at all" do
        expect(Plupp).to receive(:repository).with(:plupp_repo).and_return(@repository)
        expect Proc.new do
          Plupp.find_by_sql(:repository => :plupp_repo)
        end.to raise_error(Exception, /requires a query/)
      end

    end

  end

  describe '#uri options' do
    it 'should transform a fully specified option hash into a URI' do
      options = {
        :adapter => 'mysql',
        :host => 'davidleal.com',
        :username => 'me',
        :password => 'mypass',
        :port => 5000,
        :database => 'you_can_call_me_al',
        :socket => 'nosock'
      }

      adapter = LazyMapper::Adapters::DataObjectsAdapter.new(:spec, options)
      expect(adapter.uri).to eq Addressable::URI.parse("mysql://me:mypass@davidleal.com:5000/you_can_call_me_al?socket=nosock")
    end

    it 'should transform a minimal options hash into a URI' do
      options = {
        :adapter => 'mysql',
        :database => 'you_can_call_me_al'
      }

      adapter = LazyMapper::Adapters::DataObjectsAdapter.new(:spec, options)
      expect(adapter.uri).to eq Addressable::URI.parse("mysql:///you_can_call_me_al")
    end

    it 'should accept the uri when no overrides exist' do
      uri = Addressable::URI.parse("protocol:///")
      expect(LazyMapper::Adapters::DataObjectsAdapter.new(:spec, uri).uri).to eq uri
    end
  end

  describe '#create' do
    before do
      @result = double('result', :to_i => 1, :insert_id => 1)

      allow(@adapter).to receive(:execute).and_return(@result)

      @property   = double('property', :field => 'property', :instance_variable_name => '@property', :serial? => false)
      @repository = double('repository')
      @model      = double('model', :storage_name => 'models', :key => [ @property ])
      @resource   = double('resource', :class => @model, :dirty_attributes => [ @property ], :instance_variable_get => 'bind value')
    end

    it 'should use only dirty properties' do
      allow(@resource).to receive(:dirty_attributes).with(no_args).and_return([ @property ])
      @adapter.create(@repository, @resource)
    end

    it 'should use the properties field accessors' do
      allow(@property).to receive(:field).with(:default).and_return('property')
      @adapter.create(@repository, @resource)
    end

    it 'should use the bind values' do
      allow(@property).to receive(:instance_variable_name).with(no_args).and_return('@property')
      allow(@resource).to receive(:instance_variable_get).with('@property').and_return('bind value')
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_returning? is false' do
      statement = 'INSERT INTO "models" ("property") VALUES (?)'
      allow(@adapter).to receive(:supports_returning?).with(no_args).and_return(false)
      allow(@adapter).to receive(:execute).with(statement, 'bind value').and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_returning? is true' do
      statement = 'INSERT INTO "models" ("property") VALUES (?) RETURNING "property"'
      allow(@property).to receive(:serial?).with(no_args).and_return(true)
      allow(@adapter).to receive(:supports_returning?).with(no_args).and_return(true)
      allow(@adapter).to receive(:execute).with(statement, 'bind value').and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_default_values? is true' do
      statement = 'INSERT INTO "models" DEFAULT VALUES'
      allow(@resource).to receive(:dirty_attributes).with(no_args).and_return([])
      allow(@adapter).to receive(:supports_default_values?).with(no_args).and_return(true)
      allow(@adapter).to receive(:execute).with(statement).and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should generate an SQL statement when supports_default_values? is false' do
      statement = 'INSERT INTO "models" () VALUES ()'
      allow(@resource).to receive(:dirty_attributes).with(no_args).and_return([])
      allow(@adapter).to receive(:supports_default_values?).with(no_args).and_return(false)
      allow(@adapter).to receive(:execute).with(statement).and_return(@result)
      @adapter.create(@repository, @resource)
    end

    it 'should return false if number of rows created is 0' do
      allow(@result).to receive(:to_i).with(no_args).and_return(0)
      expect(@adapter.create(@repository, @resource)).to be false
    end

    it 'should return true if number of rows created is 1' do
      allow(@result).to receive(:to_i).with(no_args).and_return(1)
      expect(@adapter.create(@repository, @resource)).to be true
    end

    it 'should set the resource primary key if the model key size is 1 and the key is serial' do
      expect(@model.key.size).to eq 1
      allow(@property).to receive(:serial?).and_return(true)
      allow(@result).to receive(:insert_id).and_return(111)
      allow(@resource).to receive(:instance_variable_set).with('@property', 111)
      @adapter.create(@repository, @resource)
    end
  end

  describe '#read' do
    before do
      @primitive  = double('primitive')
      @property   = double('property', :field => 'property', :primitive => @primitive)
      @properties = double('properties', :defaults => [ @property ])
      @repository = double('repository', :kind_of? => true)
      @model      = double('model', :properties => @properties, :< => true, :inheritance_property => nil, :key => [ @property ], :storage_name => 'models')
      @key        = double('key')
      @resource   = double('resource')
      @collection = double('collection', :first => @resource)

      @reader     = double('reader', :close => true, :next! => false)
      @command    = double('command', :set_types => nil, :execute_reader => @reader)
      @connection = double('connection', :close => true, :create_command => @command)

      allow(LazyMapper::Connection).to receive(:new).and_return(@connection)
      allow(LazyMapper::Collection).to receive(:new).and_return(@collection)
    end

    it 'should lookup the model properties with the repository' do
      allow(@model).to receive(:properties).with(:default).and_return(@properties)
      @adapter.read(@repository, @model, @key)
    end

    it 'should use the model default properties' do
      allow(@properties).to receive(:defaults).with(no_args).and_return([ @property ])
      @adapter.read(@repository, @model, @key)
    end

    it 'should create a collection under the hood for retrieving the resource' do
      allow(LazyMapper::Collection).to receive(:new).with(@repository, @model, { @property => 0 }).and_return(@collection)
      allow(@reader).to receive(:next!).and_return(true)
      allow(@reader).to receive(:values).with(no_args).and_return({ :property => 'value' })
      allow(@collection).to receive(:load).with({ :property => 'value' })
      allow(@collection).to receive(:first).with(no_args).and_return(@resource)
      expect(@adapter.read(@repository, @model, @key)).to eq @resource
    end

    it 'should use the bind values' do
      allow(@command).to receive(:execute_reader).with(@key).and_return(@reader)
      @adapter.read(@repository, @model, @key)
    end

    it 'should generate an SQL statement' do
      statement = 'SELECT "property" FROM "models" WHERE "property" = ? LIMIT 1'
      allow(@model).to receive(:key).with(:default).and_return([ @property ])
      allow(@connection).to receive(:create_command).with(statement).and_return(@command)
      @adapter.read(@repository, @model, @key)
    end

    it 'should generate an SQL statement with composite keys' do
      other_property = double('other property')
      allow(other_property).to receive(:field).with(:default).and_return('other')

      allow(@model).to receive(:key).with(:default).and_return([ @property, other_property ])

      statement = 'SELECT "property" FROM "models" WHERE "property" = ? AND "other" = ? LIMIT 1'
      allow(@connection).to receive(:create_command).with(statement).and_return(@command)

      @adapter.read(@repository, @model, @key)
    end

    it 'should set the return types to the property primitives' do
      allow(@command).to receive(:set_types).with([ @primitive ])
      @adapter.read(@repository, @model, @key)
    end

    it 'should close the reader' do
      allow(@reader).to receive(:close).with(no_args)
      @adapter.read(@repository, @model, @key)
    end

    it 'should close the connection' do
      allow(@connection).to receive(:close).with(no_args)
      @adapter.read(@repository, @model, @key)
    end
  end

  describe '#update' do
    before do
      @result = double('result', :to_i => 1)

      allow(@model).to receive(:execute).and_return(@result)

      @property = double('property', :field => 'property', :instance_variable_name => '@property', :serial? => false)
      @model    = double('model', :storage_name => 'models', :key => [ @property ])
      @resource = double('resource', :class => @model, :dirty_attributes => [ @property ], :instance_variable_get => 'bind value')
    end

    it 'should use only dirty properties' do
      allow(@resource).to receive(:dirty_attributes).with(no_args).and_return([ @property ])
      @adapter.update(@repository, @resource)
    end

    it 'should use the properties field accessors' do
      allow(@property).to receive(:field).with(:default).twice.and_return('property')
      @adapter.update(@repository, @resource)
    end

    it 'should use the bind values' do
      allow(@property).to receive(:instance_variable_name).with(no_args).twice.and_return('@property')
      allow(@resource).to receive(:instance_variable_get).with('@property').twice.and_return('bind value')
      allow(@model).to receive(:key).with(:default).and_return([ @property ])
      allow(@adapter).to receive(:execute).with(anything, 'bind value', 'bind value').and_return(@result)
      allow(@adapter).to receive(@repository, @resource)
    end

    it 'should generate an SQL statement' do
      statement = 'UPDATE "models" SET "property" = ? WHERE "property" = ?'
      allow(@adapter).to receive(:execute).with(statement, anything, anything).and_return(@result)
      @adapter.update(@repository, @resource)
    end

    it 'should generate an SQL statement with composite keys' do
      other_property = double('other property', :instance_variable_name => '@other')
      allow(other_property).to receive(:field).with(:default).and_return('other')

      allow(@model).to receive(:key).with(:default).and_return([ @property, other_property ])

      statement = 'UPDATE "models" SET "property" = ? WHERE "property" = ? AND "other" = ?'
      allow(@adapter).to receive(:execute).with(statement, anything, anything, anything).and_return(@result)

      @adapter.update(@repository, @resource)
    end

    it 'should return false if number of rows updated is 0' do
      allow(@result).to receive(:to_i).with(no_args).and_return(0)
      expect(@adapter.update(@repository, @resource)).to be false
    end

    it 'should return true if number of rows updated is 1' do
      allow(@result).to receive(:to_i).with(no_args).and_return(1)
      expect(@adapter.update(@repository, @resource)).to be true
    end

    it 'should not try to update if there are no dirty attributes' do
      allow(@resource).to receive(:dirty_attributes).with(no_args).and_return([])
      expect(@adapter.update(@repository, @resource)).to be false
    end
  end

  describe '#delete' do
    before do
      @result = double('result', :to_i => 1)

      allow(@adapter).to receive(:execute).and_return(@result)

      @property   = double('property', :instance_variable_name => '@property', :field => 'property')
      @repository = double('repository')
      @model      = double('model', :storage_name => 'models', :key => [ @property ])
      @resource   = double('resource', :class => @model, :instance_variable_get => 'bind value')
    end

    it 'should use the properties field accessors' do
      allow(@property).to receive(:field).with(:default).and_return('property')
      @adapter.delete(@repository, @resource)
    end

    it 'should use the bind values' do
      allow(@property).to receive(:instance_variable_name).with(no_args).and_return('@property')
      allow(@resource).to receive(:instance_variable_get).with('@property').and_return('bind value')

      allow(@model).to receive(:key).with(:default).and_return([ @property ])

      allow(@adapter).to receive(:execute).with(anything, 'bind value').and_return(@result)

      @adapter.delete(@repository, @resource)
    end

    it 'should generate an SQL statement' do
      statement = 'DELETE FROM "models" WHERE "property" = ?'
      allow(@adapter).to receive(:execute).with(statement, anything).and_return(@result)
      @adapter.delete(@repository, @resource)
    end

    it 'should generate an SQL statement with composite keys' do
      other_property = double('other property', :instance_variable_name => '@other')
      allow(other_property).to receive(:field).with(:default).and_return('other')

      allow(@model).to receive(:key).with(:default).and_return([ @property, other_property ])

      statement = 'DELETE FROM "models" WHERE "property" = ? AND "other" = ?'
      allow(@adapter).to receive(:execute).with(statement, anything, anything).and_return(@result)
      @adapter.delete(@repository, @resource)
    end

    it 'should return false if number of rows deleted is 0' do
      allow(@result).to receive(:to_i).with(no_args).and_return(0)
      expect(@adapter.delete(@repository, @resource)).to be false
    end

    it 'should return true if number of rows deleted is 1' do
      allow(@result).to receive(:to_i).with(no_args).and_return(1)
      expect(@adapter.delete(@repository, @resource)).to be true
    end
  end

  describe '#read_set' do
    it 'needs specs'
  end

  describe "when upgrading tables" do
    it "should raise NotImplementedError when #storage_exists? is called" do
      expect { @adapter.storage_exists?("cheeses") }.to raise_error(NotImplementedError)
    end

    describe "#upgrade_model_storage" do
      it "should call #create_model_storage" do
        allow(@adapter).to receive(:create_model_storage).with(nil, Cheese).and_return(true)
        expect(@adapter.upgrade_model_storage(nil, Cheese)).to eq Cheese.properties
      end

      it "should check if all properties of the model have columns if the table exists" do
        allow(@adapter).to receive(:field_exists?).with("cheeses", "id").and_return(true)
        allow(@adapter).to receive(:field_exists?).with("cheeses", "name").and_return(true)
        allow(@adapter).to receive(:field_exists?).with("cheeses", "color").and_return(true)
        allow(@adapter).to receive(:field_exists?).with("cheeses", "notes").and_return(true)
        allow(@adapter).to receive(:storage_exists?).with("cheeses").and_return(true)
        expect(@adapter.upgrade_model_storage(nil, Cheese)).to eq []
      end

      it "should create and execute add column statements for columns that dont exist" do
        allow(@adapter).to receive(:field_exists?).with("cheeses", "id").and_return(true)
        allow(@adapter).to receive(:field_exists?).with("cheeses", "name").and_return(true)
        allow(@adapter).to receive(:field_exists?).with("cheeses", "color").and_return(true)
        allow(@adapter).to receive(:field_exists?).with("cheeses", "notes").and_return(false)
        allow(@adapter).to receive(:storage_exists?).with("cheeses").and_return(true)
        connection = double("connection")
        allow(connection).to receive(:close)
        allow(@adapter).to receive(:create_connection).and_return(connection)
        statement = double("statement")
        command = double("command")
        result = double("result")
        allow(result).to receive(:to_i).and_return(1)
        allow(command).to receive(:execute_non_query).and_return(result)
        allow(connection).to receive(:create_command).with(statement).and_return(command)
        allow(@adapter).to receive(:alter_table_add_column_statement).with("cheeses",
                                                                             {
                                                                               :name => "notes",
                                                                               :primitive => "VARCHAR",
                                                                               :size => 100
                                                                             }).and_return(statement)
        expect(@adapter.upgrade_model_storage(nil, Cheese)).to eq [Cheese.notes]
      end
    end
  end

  describe '#execute' do
    before do
      @mock_command = double('Command', :execute_non_query => nil)
      @mock_db = double('DB Connection', :create_command => @mock_command, :close => true)

      allow(@adapter).to receive(:create_connection).and_return(@mock_db)
    end

    it 'should #create_command from the sql passed' do
      allow(@mock_db).to receive(:create_command).with('SQL STRING').and_return(@mock_command)
      @adapter.execute('SQL STRING')
    end

    it 'should pass any additional args to #execute_non_query' do
      allow(@mock_command).to receive(:execute_non_query).with(:args)
      @adapter.execute('SQL STRING', :args)
    end

    it 'should return the result of #execute_non_query' do
      allow(@mock_command).to receive(:execute_non_query).and_return(:result_set)
      expect(@adapter.execute('SQL STRING')).to eq :result_set
    end

    it 'should log any errors, then re-raise them' do
      pending
      @mock_command.stub(:execute_non_query).and_raise("Oh Noes!")
      #LazyMapper.logger.stub(:error)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end

    it 'should always close the db connection' do
      allow(@mock_command).to receive(:execute_non_query).and_raise("Oh Noes!")
      allow(@mock_db).to receive(:close)

      expect { @adapter.execute('SQL STRING') }.to raise_error("Oh Noes!")
    end
  end

  describe '#query' do
    before do
      @mock_reader = double('Reader', :fields => ['id', 'UserName', 'AGE'],
        :values => [1, 'rando', 27],
        :close => true)
      @mock_command = double('Command', :execute_reader => @mock_reader)
      @mock_db = double('DB Connection', :create_command => @mock_command, :close => true)

      #make the while loop run exactly once
      allow(@mock_reader).to receive(:next!).and_return(true, nil)
      allow(@adapter).to receive(:create_connection).and_return(@mock_db)
    end

    it 'should #create_command from the sql passed' do
      allow(@mock_db).to receive(:create_command).with('SQL STRING').and_return(@mock_command)
      @adapter.query('SQL STRING')
    end

    it 'should pass any additional args to #execute_reader' do
      allow(@mock_command).to receive(:execute_reader).with(:args).and_return(@mock_reader)
      @adapter.query('SQL STRING', :args)
    end

    describe 'returning multiple fields' do

      it 'should underscore the field names as members of the result struct' do
        allow(@mock_reader).to receive(:fields).and_return(['id', 'UserName', 'AGE'])
        result = @adapter.query('SQL STRING')
        expect(result.first.members).to eq [:id, :user_name, :age]
      end

      it 'should convert each row into the struct' do
        allow(@mock_reader).to receive(:values).and_return([1, 'rando', 27])

        @adapter.query('SQL STRING')
      end

      it 'should add the row structs into the results array' do
        results = @adapter.query('SQL STRING')

        expect(results).to be_kind_of(Array)

        row = results.first
        expect(row).to be_kind_of(Struct)

        expect(row.id).to eq 1
        expect(row.user_name).to eq 'rando'
        expect(row.age).to eq 27
      end

    end

    describe 'returning a single field' do

      it 'should add the value to the results array' do
        allow(@mock_reader).to receive(:fields).and_return(['username'])
        allow(@mock_reader).to receive(:values).and_return(['rando'])

        results = @adapter.query('SQL STRING')

        expect(results).to be_kind_of(Array)
        expect(results.first).to eq 'rando'
      end

    end

    it 'should log any errors, then re-raise them' do
      pending
      @mock_command.stub(:execute_non_query).and_raise("Oh Noes!")
      #LazyMapper.logger.stub(:error)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end

    it 'should always close the db connection' do
      allow(@mock_command).to receive(:execute_non_query).and_raise("Oh Noes!")
      allow(@mock_db).to receive(:close)

      expect { @adapter.execute('SQL STRING') }.to raise_error("Oh Noes!")
    end
  end
end
