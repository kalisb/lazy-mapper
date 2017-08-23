require 'sqlite3'
module LazyMapper
  module Adapters
    class Sqlite3Adapter < DefaultAdapter
      # TypeMap for SQLite 3 databases.
      #
      # @return <LazyMapper::TypeMap> default TypeMap for SQLite 3 databases.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Integer).to('INTEGER')
          tm.map(Class).to('VARCHAR')
        end
      end

      def storage_exists?(table_name)
        size = 0
        execute('PRAGMA table_info(\'' + table_name + '\')').affected_rows.each { size += 1 }
        size > 0
      end

      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row[1] == column_name
        end
      end

      def query_table(storage_name)
        rows = []
        execute('PRAGMA table_info(\'' + storage_name + "')").affected_rows.each do |row|
          rows << row
        end
        rows
      end

      protected

      def normalize_uri(uri_or_options)
        uri = super
        uri.path = File.join(Dir.pwd, File.dirname(uri.path), File.basename(uri.path)) unless File.exist?(uri.path) || uri.path == ':memory:'
        uri
      end

      private

      module SQL
        private

        def create_table_statement(model)
          statement = "CREATE TABLE #{model.storage_name(name)} ("
          statement << model.properties.collect { |p| property_schema_statement(property_schema_hash(p, model)) } * ', '

          if (key = model.properties.key).any?
            statement << ", PRIMARY KEY(#{key.collect { |p| p.field(name) } * ', '})"
          end

          statement << ')'
          statement.compress_lines
        end
      end

      include SQL
    end
  end
  module Sqlite3
    class Command < LazyMapper::Command
      def execute_non_query(*args)
        rows = @connection.execute @text, *args
        result = Result.new(self, rows, @connection.last_insert_row_id)
        result
      end
    end
    class Reader < LazyMapper::Reader
    end
    class Connection < LazyMapper::Connection
      def self.acquire(uri)
        conn = nil
        @connection_lock.synchronize do
          if @available_connections[uri].empty?
            conn = if uri.path == ':memory:'
                     SQLite3::Database.new uri
                   else
                     SQLite3::Database.new uri.path
                   end
            conn.send(:initialize, uri)
            at_exit { conn.real_close }
          else
            conn = @available_connections[uri].pop
          end

          @reserved_connections << conn
        end

        conn
      end

      def self.close
        @connection.close
      end
    end
  end
end
module SQLite3
  class Database
    def create_command(text)
      concrete_command.new(self, text)
    end

    def real_close
      self.close
    end

    private
    def concrete_command
      @concrete_command || begin

        class << self
          attr_reader :concrete_command
        end

        @concrete_command = LazyMapper.const_get('Sqlite3').const_get('Command')
      end
    end
  end
end
