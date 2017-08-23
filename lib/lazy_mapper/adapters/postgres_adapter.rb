require 'pg'
module LazyMapper
  module Adapters
    class PostgresAdapter < DefaultAdapter
      def storage_exists?(table_name)
        exists = false
        execute('SELECT to_regclass(\'' + table_name + '\')').each { |row| exists = row['to_regclass'] }
        exists != nil
      end

      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row['column_name'] == column_name
        end
      end

      def query_table(storage_name)
        rows = []
        execute('select column_name from information_schema.columns where table_name=\'' + storage_name + '\'').each { |row| rows << row }
        rows
      end

      def create_table_statement(model)
        add_sequences(model)
        super
      end

      def equality_operator(query, table_name, operator, property, qualify, bind_value)
        case bind_value
        when Array             then "#{property_to_column_name(table_name, property, qualify)} IN $1"
        when Range             then "#{property_to_column_name(table_name, property, qualify)} BETWEEN $1"
        when NilClass          then "#{property_to_column_name(table_name, property, qualify)} = $1"
        when LazyMapper::Query then
          query.merge_sub_select_conditions(operator, property, bind_value)
          "#{property_to_column_name(table_name, property, qualify)} IN (#{query_read_statement(bind_value)})"
        else "#{property_to_column_name(table_name, property, qualify)} = $1"
        end
      end

      def create_statement(model, dirty_attributes, _identity_field)
        statement = "INSERT INTO #{quote_table_name(model.storage_name(name))} "

        statement << if dirty_attributes.empty? && supports_default_values?
                       'DEFAULT VALUES'
                     else
                       <<-EOS.compress_lines
                        (#{dirty_attributes.map { |p| quote_column_name(p.field(name)) }.join(', ')})
                        VALUES
                        (#{1.upto(dirty_attributes.size).map { |val| "$#{val}" }.join(', ')})
                       EOS
                     end
        statement
      end

     def update_statement(model, dirty_attributes, key)
       <<-EOS.compress_lines
         UPDATE #{quote_table_name(model.storage_name(name))}
         SET #{dirty_attributes.map { |p| "#{quote_column_name(p.field(name))} = $1" }.join(', ')}
         WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = $2" }.join(' AND ')}
       EOS
     end

    def delete_statement(model, key)
      <<-EOS.compress_lines
        DELETE FROM #{quote_table_name(model.storage_name(name))}
        WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = $1" }.join(' AND ')}
      EOS
    end

       def count(_repository, property, query)
         parameters = query.parameters
         execute(aggregate_value_statement(:count, property, query), *parameters).affected_rows.first['count'].to_i
       end
    module SQL
      def property_schema_statement(schema)
        statement = super

        if schema.key?(:sequence_name)
          statement << " DEFAULT nextval('#{schema[:sequence_name]}') NOT NULL"
        end

        statement
      end

       def sequence_exists?(model, property)
         statement = <<-EOS.compress_lines
            SELECT COUNT(*)
            FROM "pg_class"
            WHERE "relkind" = 'S' AND "relname" = $1
          EOS

         result =  execute(statement, sequence_name(model, property))
         result.affected_rows[0]["count"].to_i > 0
       end

       def create_sequence(model, property)
         return if sequence_exists?(model, property)
         execute(create_sequence_statement(model, property))
       end

       def create_sequence_statement(model, property)
         "CREATE SEQUENCE #{quote_column_name(sequence_name(model, property))}"
       end

       def add_sequences(model)
         model.properties(name).each do |property|
           create_sequence(model, property) if property.serial?
         end
       end

       def property_schema_hash(property, model)
         schema = super
         schema[:sequence_name] = sequence_name(model, property) if property.serial?
         schema
       end

       def sequence_name(model, property)
         "#{model.storage_name(name)}_#{property.field(name)}_seq"
       end
    end
    include SQL
    end
  end
  module Postgres
    class Command < LazyMapper::Command
      def execute_non_query(*args)
        result = @connection.exec @text, args
        result
      end
    end
    class Connection < LazyMapper::Connection
      def self.acquire(uri)
        conn = nil
        @connection_lock.synchronize do
          if @available_connections[uri].empty?
            path = uri.path.delete '/'
            conn = PG.connect dbname: path, user: uri.user, password: uri.password
            conn.send(:initialize, uri)
            at_exit { conn.real_close }
          else
            conn = @available_connections[uri].pop
          end

          @reserved_connections << conn
        end

        conn
      end
    end
  end
end
module PG
  class Connection
    def real_close
      self.finish unless self.finished?
    end

    def create_command(text)
      concrete_command.new(self, text)
    end

    private
    def concrete_command
      @concrete_command || begin

        class << self
          attr_reader :concrete_command
        end

        @concrete_command = LazyMapper.const_get('Postgres').const_get('Command')
      end
    end
  end

  class Result
    def size
      result_status
    end

    def insert_id
      oid_value
    end

    def affected_rows
      self.to_a
    end

    def to_i
      self.to_a.size
    end
  end
end
