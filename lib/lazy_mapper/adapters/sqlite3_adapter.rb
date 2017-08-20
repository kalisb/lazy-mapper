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
        execute('PRAGMA table_info(\'' + table_name + '\')').each { |row|
          size += 1
        }
        size > 0
      end

      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row[1] == column_name
        end
      end

      def query_table(storage_name)
        rows = []
        execute('PRAGMA table_info(\'' + storage_name + "')").each { |row|
          rows << row
        }
        rows
      end

      protected

      def normalize_uri(uri_or_options)
        uri = super
        uri.path = File.join(Dir.pwd, File.dirname(uri.path), File.basename(uri.path)) unless File.exists?(uri.path) or uri.path == ':memory:'
        uri
      end

      private

      module SQL
        private

        def create_table_statement(model)
          statement = "CREATE TABLE #{model.storage_name(name)} ("
          array = model.properties.collect {|p| property_schema_hash(p, model) }

          statement << "#{model.properties.collect {|p| property_schema_statement(property_schema_hash(p, model)) } * ', '}"

          if (key = model.properties.key).any?
            statement << ", PRIMARY KEY(#{ key.collect { |p| p.field(name) } * ', '})"
          end

          statement << ')'
          statement.compress_lines
        end
      end

      include SQL
    end # class Sqlite3Adapter
  end # module Adapters
  module Sqlite3
    class Connection
      def self.acquire(uri)
        if (uri.path == ':memory:')
          @connection = SQLite3::Database.new uri
        else
          @connection = SQLite3::Database.new uri.path
        end
      end

      def self.close
        @connection.close
      end
    end
  end
end # module LazyMapper
