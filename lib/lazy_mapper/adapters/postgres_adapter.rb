require 'pg'
class PG::Connection
  def execute(statement)
    self.exec statement
  end

  def execute(statement, *args)
    self.exec(statement, *args)
  end
end

module LazyMapper
  module Adapters
    class PostgresAdapter < DefaultAdapter
      def storage_exists?(table_name)
        exists = false
        execute('SELECT to_regclass(\'' + table_name + '\')').each { |row|
          exists = row['to_regclass']
        }
        exists != nil
      end

      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row['column_name'] == column_name
        end
      end

      def query_table(storage_name)
        rows = []
        execute('select column_name from information_schema.columns where table_name=\'' + storage_name + '\'').each { |row|
          rows << row
        }
        rows
      end

      module SQL
        def create_table_statement(model)
          statement = "CREATE TABLE #{model.storage_name(name)} ("
          array = model.properties.collect {|p| property_schema_hash(p, model) }
          array.each { |prop|
            statement << "#{prop[:name]} #{prop[:primitive]}"
          }
          if (key = model.properties.key).any?
            statement << " PRIMARY KEY(#{ key.collect { |p| p.field(name) } * ', '})"
          end

          statement << ')'
          statement.compress_lines
        end
      end
    end
  end
  module Postgres
    class Connection
      def self.acquire(uri)
        @connection = PG.connect :dbname => 'testdb', :user => 'postgres', :password => 'test'
      end
    end
  end
end
