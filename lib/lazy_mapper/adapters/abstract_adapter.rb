module LazyMapper
  module Adapters

    class AbstractAdapter
      attr_accessor :resource_naming_convention, :field_naming_convention

      def self.type_map
        @type_map ||= TypeMap.new
      end

      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention

      # methods dealing with transactions

      #
      # Pushes the given Transaction onto the per thread Transaction stack so
      # that everything done by this Adapter is done within the context of said
      # Transaction.
      #
      def push_transaction(transaction)
        @transactions[Thread.current] << transaction
      end

      #
      # Pop the 'current' Transaction from the per thread Transaction stack so
      # that everything done by this Adapter is no longer necessarily within the
      # context of said Transaction.
      #
      def pop_transaction
        @transactions[Thread.current].pop
      end

      #
      # Retrieve the current transaction for this Adapter.
      #
      # Everything done by this Adapter is done within the context of this
      # Transaction.
      #
      def current_transaction
        @transactions[Thread.current].last
      end

      #
      # Returns whether we are within a Transaction.
      #
      def within_transaction?
        !current_transaction.nil?
      end

      protected

      def normalize_uri(uri_or_options)
        uri_or_options
      end

      private

      # Instantiate an Adapter by passing it a LazyMapper::Repository
      # connection string for configuration.
      def initialize(name, uri_or_options)
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller                                     unless Symbol === name
        raise ArgumentError, "+uri_or_options+ should be a Hash, a Addressable::URI or a String but was #{uri_or_options.class}", caller unless [ Hash, Addressable::URI, String ].any? { |k| k === uri_or_options }

        @name = name
        @uri  = normalize_uri(uri_or_options)
        @transactions = Hash.new { |hash, key| hash[key] = [] }

        @resource_naming_convention = NamingConventions::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Underscored
      end
    end # class AbstractAdapter
  end # module Adapters
  class Command
    attr_reader :text, :timeout, :connection

    # initialize creates a new Command object
    def initialize(connection, text)
      @connection, @text = connection, text
    end
  end
  class Connection

    def self.inherited(base)
      base.instance_variable_set('@connection_lock', Mutex.new)
      base.instance_variable_set('@available_connections', Hash.new { |h,k| h[k] = [] })
      base.instance_variable_set('@reserved_connections', Set.new)

      if driver_module_name = base.name.split('::')[-2]
        driver_module = LazyMapper::const_get(driver_module_name)
        driver_module.class_eval <<-EOS
          def self.logger
            @logger
          end
          def self.logger=(logger)
            @logger = logger
          end
        EOS

        driver_module.logger = LazyMapper::Logger
      end
    end

    def self.prepare(statement)
    end

    def self.new(uri)
      uri = uri.is_a?(String) ? Addressable::URI::parse(uri) : uri
      LazyMapper.const_get(uri.scheme.capitalize)::Connection.acquire(uri)
    end

    def self.acquire(connection_uri)
      conn = nil
      connection_string = connection_uri.to_s

      @connection_lock.synchronize do
        unless @available_connections[connection_string].empty?
          conn = @available_connections[connection_string].pop
        else
          conn = allocate
          conn.send(:initialize, connection_uri)
          at_exit { conn.real_close }
        end

        @reserved_connections << conn
      end

      return conn
    end

    def self.release(connection)
      @connection_lock.synchronize do
        if @reserved_connections.delete?(connection)
          @available_connections[connection.to_s] << connection
        end
      end
      return nil
    end

    def close
      self.class.release(self)
    end

    #####################################################
    # Standard API Definition
    #####################################################
    def to_s
      @uri.to_s
    end

    def initialize(uri)
      raise NotImplementedError.new
    end

    def real_close
      raise NotImplementedError.new
    end

    def create_command(text)
      concrete_command.new(self, text)
    end

    private
    def concrete_command
      @concrete_command || begin

        class << self
          private
          def concrete_command
            @concrete_command
          end
        end

        @concrete_command = LazyMapper::const_get(self.class.name.split('::')[-2]).const_get('Command')
      end
    end

  end
end # module LazyMapper
