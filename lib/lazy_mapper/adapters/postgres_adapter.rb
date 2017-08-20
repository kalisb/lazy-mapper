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
    class Connection
      def self.acquire(uri)
        @connection = PG.connect :dbname => 'postgres', :user => 'postgres', :password => 'test'
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
	
	def to_i() 
		self.to_a.size
	end
  end
end
