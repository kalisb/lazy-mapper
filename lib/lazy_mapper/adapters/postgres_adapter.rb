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

	  def equality_operator(query, table_name, operator, property, qualify, bind_value)
          case bind_value
            when Array             then "#{property_to_column_name(table_name, property, qualify)} IN $1"
            when Range             then "#{property_to_column_name(table_name, property, qualify)} BETWEEN $1"
            when NilClass          then "#{property_to_column_name(table_name, property, qualify)} IS $1"
            when LazyMapper::Query then
              query.merge_sub_select_conditions(operator, property, bind_value)
              "#{property_to_column_name(table_name, property, qualify)} IN (#{query_read_statement(bind_value)})"
            else "#{property_to_column_name(table_name, property, qualify)} = $1"
          end
      end

	  def create_statement(model, dirty_attributes, identity_field)
          statement = "INSERT INTO #{quote_table_name(model.storage_name(name))} "

          if dirty_attributes.empty? && supports_default_values?
            statement << 'DEFAULT VALUES'
          else
            statement << <<-EOS.compress_lines
              (#{dirty_attributes.map { |p| quote_column_name(p.field(name)) }.join(', ')})
              VALUES
              (#{1.upto(dirty_attributes.size).map { |val| "$#{val}" }.join(', ')})
            EOS
          end

          if supports_returning? && identity_field
            statement << " RETURNING #{quote_column_name(identity_field.field(name))}"
          end

          statement
       end

	   def update_statement(model, dirty_attributes, key)
          <<-EOS.compress_lines
            UPDATE #{quote_table_name(model.storage_name(name))}
            SET #{dirty_attributes.map { |p| "#{quote_column_name(p.field(name))} = $2" }.join(', ')}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = $1" }.join(' AND ')}
          EOS
       end

	   def delete_statement(model, key)
          <<-EOS.compress_lines
            DELETE FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = $1" }.join(' AND ')}
          EOS
       end
    end
  end
  module Postgres
    class Command < LazyMapper::Command
      def execute_non_query(*args)
        result = @connection.exec @text, *args
        result
      end
    end
    class Connection < LazyMapper::Connection
      def self.acquire(uri)
        conn = nil
        @connection_lock.synchronize do
          unless @available_connections[uri].empty?
            conn = @available_connections[uri].pop
          else
            path = uri.path.delete '/'
            conn = PG.connect :dbname => path, :user => uri.user, :password => uri.password
            conn.send(:initialize, uri)
            at_exit { conn.real_close }
          end

          @reserved_connections << conn
        end

        return conn
      end
    end
  end

  class PG::Connection
    def real_close
      self.close
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

        @concrete_command = LazyMapper::const_get('Postgres').const_get('Command')
      end
    end
  end

  class PG::Result
  	def size()
  		result_status
  	end

  	def insert_id()
  		oid_value
  	end

    def affected_rows
      self.to_a
    end

  	def to_i()
  		self.to_a.size
  	end
  end
end
