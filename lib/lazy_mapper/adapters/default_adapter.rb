gem 'addressable', '>=1.0.4'
require 'addressable/uri'
module LazyMapper
  module Adapters

    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the LazyMapper.
    class DefaultAdapter < AbstractAdapter

      # Default TypeMap for all data object based adapters.
      #
      # @return <LazyMapper::TypeMap> default TypeMap for data objects adapters.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Integer).to('INT')
          tm.map(String).to('VARCHAR').with(:size => 25)
          tm.map(Class).to('VARCHAR').with(:size => 25)
#          tm.map(BigDecimal).to('DECIMAL').with(:scale => Property::DEFAULT_SCALE, :precision => Property::DEFAULT_PRECISION)
#          tm.map(Float).to('FLOAT').with(:scale => Property::DEFAULT_SCALE, :precision => Property::DEFAULT_PRECISION)
          tm.map(DateTime).to('DATETIME')
          tm.map(Date).to('DATE')
          tm.map(Time).to('TIMESTAMP')
          tm.map(TrueClass).to('BOOLEAN')
          tm.map(Object).to('TEXT')
        end
      end

      # all of our CRUD
      # Methods dealing with a single resource object
      def create(repository, resource)
        dirty_attributes = resource.dirty_attributes

        identity_field = begin
          key = resource.class.key(name)
          key.first if key.size == 1
        end

        statement = create_statement(resource.class, dirty_attributes, identity_field)
        bind_values = dirty_attributes.map { |p| resource.instance_variable_get(p.instance_variable_name) }
        result = execute(statement, *bind_values)
        result.each { |row|
          puts row
        }
        return false if result.size != 1

        if identity_field
          resource.instance_variable_set(identity_field.instance_variable_name, result.insert_id)
        end

        true
      end

      def read(repository, model, bind_values)
        properties = model.properties(name).defaults

        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]

        key = model.key(name)
        set = Collection.new(repository, model, properties_with_indexes)

        statement = read_statement(model, properties, key)

        with_connection do |connection|
          command = connection.create_command(statement)
          command.set_types(properties.map { |p| p.primitive })

          begin
            reader = command.execute_reader(*bind_values)
            set.load(reader.values) if reader.next!
            set.first
          ensure
            reader.close if reader
          end
        end
      end

      def read_set(repository, query)
       read_set_with_sql(repository,
                         query.model,
                         query.fields,
                         query_read_statement(query),
                         query.parameters,
                         query.reload?)
      end

      def update(repository, resource)
        dirty_attributes = resource.dirty_attributes

        return false if dirty_attributes.empty?

        key = resource.class.key(name)

        statement = update_statement(resource.class, dirty_attributes, key)
        bind_values = dirty_attributes.map { |p| resource.instance_variable_get(p.instance_variable_name) }
        key.each { |p| bind_values << resource.instance_variable_get(p.instance_variable_name) }

        execute(statement, *bind_values).to_i == 1
      end

      def delete(repository, resource)
        key = resource.class.key(name)

        statement = delete_statement(resource.class, key)
        bind_values = key.map { |p| resource.instance_variable_get(p.instance_variable_name) }

        execute(statement, *bind_values).size == 1
      end

      # Database-specific method
      def execute(statement, *args)
        with_connection do |connection|
          puts statement
          connection.execute(statement, args)
        end
      end

      def query(statement, *args)
        with_reader(statement, args) do |reader|
          results = []

          if (fields = reader.fields).size > 1
            fields = fields.map { |field| field.downcase.to_sym }
            struct = Struct.new(*fields)

            while(reader.next!) do
              results << struct.new(*reader.values)
            end
          else
            while(reader.next!) do
              results << reader.values.at(0)
            end
          end

          results
        end
      end

      def upgrade_model_storage(repository, model)
        table_name = model.storage_name(name)

        if success = create_model_storage(repository, model)
          return model.properties(name)
        end

        properties = []

        model.properties(name).each do |property|
          schema_hash = property_schema_hash(property, model)
          next if field_exists?(table_name, schema_hash[:name])
          statement = alter_table_add_column_statement(table_name, schema_hash)
          result = execute(statement)
          properties << property #if result.to_i == 1
        end

        properties
      end

      def create_model_storage(repository, model)
        return false if storage_exists?(model.storage_name(name))
        fail = false
        fail = true unless execute(create_table_statement(model))
        #(create_index_statements(model) + create_unique_index_statements(model)).each do |sql|
        #  fail = true unless execute(sql).to_i == 1
        #end
        !fail
      end

      def destroy_model_storage(repository, model)
        execute(drop_table_statement(model))
      end

      def transaction_primitive
        LazyMapper::Transaction.create_for_uri(@uri)
      end

      protected

      def normalize_uri(uri_or_options)
        if String === uri_or_options
          uri_or_options = Addressable::URI.parse(uri_or_options)
        end
        if Addressable::URI === uri_or_options
          return uri_or_options.normalize
        end

        adapter = uri_or_options.delete(:adapter)
        user = uri_or_options.delete(:username)
        password = uri_or_options.delete(:password)
        host = (uri_or_options.delete(:host) || "")
        port = uri_or_options.delete(:port)
        database = uri_or_options.delete(:database)
        query = uri_or_options.to_a.map { |pair| pair.join('=') }.join('&')
        query = nil if query == ""
        return Addressable::URI.new(
          :scheme => adapter, :user => user, :password => password, :host => host, :port => port, :path => database,  :query => query
        )
      end

      # TODO: clean up once transaction related methods move to dm-more/dm-transactions
      def create_connection
        if within_transaction?
          current_transaction.primitive_for(self).connection
        else
          # LazyMapper::Connection.new(uri) will give you back the right
          # driver based on the Uri#scheme.
          LazyMapper::Connection.new(@uri)
        end
      end

      def close_connection(connection)
        connection.close unless within_transaction? && current_transaction.primitive_for(self).connection == connection
      end

      private

      def initialize(name, uri_or_options)
        super

        # Default the driver-specifc logger to LazyMapper's logger
        if driver_module = DataObjects.const_get(@uri.scheme.capitalize) rescue nil
          driver_module.logger = LazyMapper.logger if driver_module.respond_to?(:logger=)
        end
      end

      def with_reader(statement, bind_values = [], &block)
        with_connection do |connection|
          reader = nil
          begin
            reader = connection.create_command(statement).execute_reader(*bind_values)
            return yield(reader)
          ensure
            reader.close if reader
          end
        end
      end

      def with_connection(&block)
        connection = nil
        begin
          connection = create_connection
          return yield(connection)
        rescue => e
          LazyMapper.logger.error(e)
          raise e
        ensure
          close_connection(connection) if connection
        end
      end

      #
      # used by find_by_sql and read_set
      #
      # @param repository<LazyMapper::Repository> the repository to read from.
      # @param model<Object>  the class of the instances to read.
      # @param properties<Array>  the properties to read. Must contain Symbols,
      #   Strings or DM::Properties.
      # @param sql<String>  the query to execute.
      # @param parameters<Array>  the conditions to the query.
      # @param do_reload<Boolean> whether to reload objects already found in the
      #   identity map.
      #
      # @return <Collection> a set of the found instances.
      def read_set_with_sql(repository, model, properties, sql, parameters, do_reload)
        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
        Collection.new(repository, model, properties_with_indexes) do |set|
          with_connection do |connection|
            rows = []
            execute(sql).each { |row|
              rows << row
            }
            puts rows
          end
        end
      end

      # This model is just for organization. The methods are included into the
      # Adapter below.
      module SQL
        private

        # Adapters requiring a RETURNING syntax for INSERT statements
        # should overwrite this to return true.
        def supports_returning?
          false
        end

        # Adapters that do not support the DEFAULT VALUES syntax for
        # INSERT statements should overwrite this to return false.
        def supports_default_values?
          true
        end

        def create_statement(model, dirty_attributes, identity_field)
          statement = "INSERT INTO #{quote_table_name(model.storage_name(name))} "

          if dirty_attributes.empty? && supports_default_values?
            statement << 'DEFAULT VALUES'
          else
            statement << <<-EOS.compress_lines
              (#{dirty_attributes.map { |p| quote_column_name(p.field(name)) }.join(', ')})
              VALUES
              (#{(['?'] * dirty_attributes.size).join(', ')})
            EOS
          end

          if supports_returning? && identity_field
            statement << " RETURNING #{quote_column_name(identity_field.field(name))}"
          end

          statement
        end

        # TODO: remove this and use query_read_statement instead
        def read_statement(model, properties, key)
          <<-EOS.compress_lines
            SELECT #{properties.map { |p| quote_column_name(p.field(name)) }.join(', ')}
            FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(' AND ')}
            LIMIT 1
          EOS
        end

        def update_statement(model, dirty_attributes, key)
          <<-EOS.compress_lines
            UPDATE #{quote_table_name(model.storage_name(name))}
            SET #{dirty_attributes.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(', ')}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(' AND ')}
          EOS
        end

        def delete_statement(model, key)
          <<-EOS.compress_lines
            DELETE FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(' AND ')}
          EOS
        end

        def query_read_statement(query)
          qualify = query.links.any?

          statement = 'SELECT '

          statement << query.fields.map do |property|
            # TODO Should we raise an error if there is no such property in the
            #      repository of the query?
            #
            #if property.model.properties(name)[property.name].nil?
            #  raise "Property #{property.model.to_s}.#{property.name.to_s} not available in repository #{name}."
            #end
            #
            table_name = property.model.storage_name(name)
            property_to_column_name(table_name, property, qualify)
          end.join(', ')

          statement << ' FROM ' << quote_table_name(query.model.storage_name(name))

          unless query.links.empty?
            joins = []
            query.links.each do |relationship|
              child_model       = relationship.child_model
              parent_model      = relationship.parent_model
              child_model_name  = child_model.storage_name(name)
              parent_model_name = parent_model.storage_name(name)
              child_keys        = relationship.child_key.to_a

              # We only do LEFT OUTER JOIN for now
              s = ' LEFT OUTER JOIN '
              s << quote_table_name(parent_model_name) << ' ON '
              parts = []
              relationship.parent_key.zip(child_keys) do |parent_key,child_key|
                part = ''
#                part = '('  # TODO: uncomment if OR conditions become possible (for links)
                part <<  property_to_column_name(parent_model_name, parent_key, qualify)
                part << ' = '
                part <<  property_to_column_name(child_model_name, child_key, qualify)
#                part << ')'  # TODO: uncomment if OR conditions become possible (for links)
                parts << part
              end
              s << parts.join(' AND ')
              joins << s
            end
            statement << joins.join
          end

          unless query.conditions.empty?
            statement << ' WHERE '
#            statement << '(' if query.conditions.size > 1  # TODO: uncomment if OR conditions become possible (for conditions)
            statement << query.conditions.map do |operator, property, bind_value|
              # TODO Should we raise an error if there is no such property in
              #      the repository of the query?
              #
              #if property.model.properties(name)[property.name].nil?
              #  raise "Property #{property.model.to_s}.#{property.name.to_s} not available in repository #{name}."
              #end
              #
              table_name = property.model.storage_name(name) if property && property.respond_to?(:model)
              case operator
                when :raw      then property
                when :eql, :in then equality_operator(query, table_name, operator, property, qualify, bind_value)
                when :not      then inequality_operator(query, table_name,operator, property, qualify, bind_value)
                when :like     then "#{property_to_column_name(table_name, property, qualify)} LIKE ?"
                when :gt       then "#{property_to_column_name(table_name, property, qualify)} > ?"
                when :gte      then "#{property_to_column_name(table_name, property, qualify)} >= ?"
                when :lt       then "#{property_to_column_name(table_name, property, qualify)} < ?"
                when :lte      then "#{property_to_column_name(table_name, property, qualify)} <= ?"
                else raise "Invalid query operator: #{operator.inspect}"
              end
            end.join(' AND ')
#            end.join(') AND (')                            # TODO: uncomment if OR conditions become possible (for conditions)
#            statement << ')' if query.conditions.size > 1  # TODO: uncomment if OR conditions become possible (for conditions)
          end

          unless query.order.empty?
            parts = []
            query.order.each do |item|
              property, direction = nil, nil

              case item
                when LazyMapper::Property
                  property = item
                when LazyMapper::Query::Direction
                  property  = item.property
                  direction = item.direction if item.direction == :desc
              end

              table_name = property.model.storage_name(name) if property && property.respond_to?(:model)

              order = property_to_column_name(table_name, property, qualify)
              order << " #{direction.to_s.upcase}" if direction

              parts << order
            end
            statement << " ORDER BY #{parts.join(', ')}"
          end

          statement << " LIMIT #{query.limit}" if query.limit
          statement << " OFFSET #{query.offset}" if query.offset && query.offset > 0

          statement
        rescue => e
          LazyMapper.logger.error("QUERY INVALID: #{query.inspect} (#{e})")
          raise e
        end

        def equality_operator(query, table_name, operator, property, qualify, bind_value)
          case bind_value
            when Array             then "#{property_to_column_name(table_name, property, qualify)} IN ?"
            when Range             then "#{property_to_column_name(table_name, property, qualify)} BETWEEN ?"
            when NilClass          then "#{property_to_column_name(table_name, property, qualify)} IS ?"
            when LazyMapper::Query then
              query.merge_sub_select_conditions(operator, property, bind_value)
              "#{property_to_column_name(table_name, property, qualify)} IN (#{query_read_statement(bind_value)})"
            else "#{property_to_column_name(table_name, property, qualify)} = ?"
          end
        end

        def inequality_operator(query, table_name, operator, property, qualify, bind_value)
          case bind_value
            when Array             then "#{property_to_column_name(table_name, property, qualify)} NOT IN ?"
            when Range             then "#{property_to_column_name(table_name, property, qualify)} NOT BETWEEN ?"
            when NilClass          then "#{property_to_column_name(table_name, property, qualify)} IS NOT ?"
            when LazyMapper::Query then
              query.merge_sub_select_conditions(operator, property, bind_value)
              "#{property_to_column_name(table_name, property, qualify)} NOT IN (#{query_read_statement(bind_value)})"
            else "#{property_to_column_name(table_name, property, qualify)} <> ?"
          end
        end

        def property_to_column_name(table_name, property, qualify)
          if qualify
            quote_table_name(table_name) + '.' + quote_column_name(property.field(name))
          else
            quote_column_name(property.field(name))
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_table_name(table_name)
          "\"#{table_name.gsub('"', '""')}\""
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_column_name(column_name)
          "\"#{column_name.gsub('"', '""')}\""
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_column_value(column_value)
          return 'NULL' if column_value.nil?

          case column_value
            when String
              if (integer = column_value.to_i).to_s == column_value
                quote_column_value(integer)
              elsif (float = column_value.to_f).to_s == column_value
                quote_column_value(integer)
              else
                "'#{column_value.gsub("'", "''")}'"
              end
            when DateTime
              quote_column_value(column_value.strftime('%Y-%m-%d %H:%M:%S'))
            when Date
              quote_column_value(column_value.strftime('%Y-%m-%d'))
            when Time
              quote_column_value(column_value.strftime('%Y-%m-%d %H:%M:%S') + ((column_value.usec > 0 ? ".#{column_value.usec.to_s.rjust(6, '0')}" : '')))
            when Integer, Float
              column_value.to_s
            when BigDecimal
              column_value.to_s('F')
            else
              column_value.to_s
          end
        end

        # Adapters that support AUTO INCREMENT fields for CREATE TABLE
        # statements should overwrite this to return true
        #
        # TODO: move to dm-more/dm-migrations
        def supports_serial?
          false
        end

        # TODO: move to dm-more/dm-migrations
        def alter_table_add_column_statement(table_name, schema_hash)
          "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{property_schema_statement(schema_hash)}"
        end

        # TODO: move to dm-more/dm-migrations
        def create_table_statement(model)
          statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("
          statement << "#{model.properties(name).collect { |p| property_schema_statement(property_schema_hash(p, model)) } * ', '}"

          if (key = model.key(name)).any?
            statement << ", PRIMARY KEY(#{ key.collect { |p| quote_column_name(p.field(name)) } * ', '})"
          end

          statement << ')'
          statement.compress_lines
        end

        # TODO: move to dm-more/dm-migrations
        def drop_table_statement(model)
          "DROP TABLE IF EXISTS #{model.storage_name(name)}"
        end

        # TODO: move to dm-more/dm-migrations
        def create_index_statements(model)
          table_name = model.storage_name(name)
          model.properties.indexes.collect do |index_name, properties|
            "CREATE INDEX #{quote_column_name('index_' + table_name + '_' + index_name)} ON " +
            "#{quote_table_name(table_name)} (#{properties.collect{|p| quote_column_name(p)}.join ','})"
          end
        end

        # TODO: move to dm-more/dm-migrations
        def create_unique_index_statements(model)
          table_name = model.storage_name(name)
          model.properties.unique_indexes.collect do |index_name, properties|
            "CREATE UNIQUE INDEX #{quote_column_name('unique_index_' + table_name + '_' + index_name)} ON " +
            "#{quote_table_name(table_name)} (#{properties.collect{|p| quote_column_name(p)}.join ','})"
          end
        end

        # TODO: move to dm-more/dm-migrations
        def property_schema_hash(property, model)
          schema = self.class.type_map[property.type].merge(:name => property.field(name))
          if property.type == String
            schema[:size] = 30
          end
          schema
        end

        # TODO: move to dm-more/dm-migrations
        def property_schema_statement(schema)
          statement = quote_column_name(schema[:name])
          statement << " #{schema[:primitive]}"

          if schema[:size]
              statement << "(#{quote_column_value(schema[:size])})"
          end

          statement
        end

        # TODO: move to dm-more/dm-migrations
        def relationship_schema_hash(relationship)
          identifier, relationship = relationship

          self.class.type_map[Fixnum].merge(:name => "#{identifier}_id") if identifier == relationship.name
        end

        # TODO: move to dm-more/dm-migrations
        def relationship_schema_statement(hash)
          property_schema_statement(hash) unless hash.nil?
        end
      end #module SQL

      include SQL

    end # class DoAdapter
  end # module Adapters
end # module LazyMapper
