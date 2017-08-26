module LazyMapper
  module Adapters
    class AbstractAdapter
      attr_accessor :resource_naming_convention, :field_naming_convention

      def self.type_map
        @type_map ||= TypeMap.new
      end

      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention

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
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller unless Symbol === name
        raise ArgumentError, "+uri_or_options+ should be a Hash, a Addressable::URI or a String but was #{uri_or_options.class}", caller unless [ Hash, Addressable::URI, String ].any? { |k| k === uri_or_options }

        @name = name
        @uri  = normalize_uri(uri_or_options)
        @transactions = Hash.new { |hash, key| hash[key] = [] }

        @resource_naming_convention = NamingConventions::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Underscored
      end
    end
  end
  class Command
    attr_reader :text, :timeout, :connection

    # initialize creates a new Command object
    def initialize(connection, text)
      @connection = connection
      @text = text
    end
  end
  class Reader
  end
  class Result
    attr_accessor :insert_id, :affected_rows

    def initialize(command, affected_rows, insert_id = nil)
      @command = command
      @affected_rows = affected_rows
      @insert_id = insert_id
    end

    def to_i
      @affected_rows
    end
  end
  class Connection
    def self.inherited(base)
      base.instance_variable_set('@connection_lock', Mutex.new)
      base.instance_variable_set('@available_connections', Hash.new { |h, k| h[k] = [] })
      base.instance_variable_set('@reserved_connections', Set.new)

      if driver_module_name = base.name.split('::')[-2]
        driver_module = LazyMapper.const_get(driver_module_name)
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

    def self.new(uri)
      uri = uri.is_a?(String) ? Addressable::URI.parse(uri) : uri
      LazyMapper.const_get(uri.scheme.capitalize)::Connection.acquire(uri)
    end

    def close
      self.class.release(self)
    end

    def to_s
      @uri.to_s
    end

    def create_command(text)
      concrete_command.new(self, text)
    end

    private
    def concrete_command
      @concrete_command || begin
        @concrete_command = LazyMapper.const_get(self.class.name.split('::')[-2]).const_get('Command')
      end
    end
  end
end
