module LazyMapper
  module Adapters
    class DefaultAdapter < AbstractAdapter
      ##
      # Default TypeMap for all data object based adapters.
      #
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Integer).to('INT')
          tm.map(String).to('VARCHAR').with(size: Property::DEFAULT_LENGTH)
          tm.map(Class).to('VARCHAR').with(size: Property::DEFAULT_LENGTH)
          tm.map(DateTime).to('DATETIME')
          tm.map(Date).to('DATE')
          tm.map(Time).to('TIMESTAMP')
          tm.map(TrueClass).to('BOOLEAN')
          tm.map(Object).to('TEXT')
        end
      end

      # all of our CRUD
      # Methods dealing with a single resource object
      def create(_repository, resource)
        dirty_attributes = resource.dirty_attributes

        identity_field = begin
          key = resource.class.key(name)
          key.first if key.size == 1 && key.first.serial?
        end

        statement = create_statement(resource.class, dirty_attributes, identity_field)
        bind_values = dirty_attributes.map { |p| resource.instance_variable_get(p.instance_variable_name) }

        result = execute(statement, *bind_values)
        if identity_field
          resource.instance_variable_set(identity_field.instance_variable_name, result.insert_id)
        end

        true
      end

      def read_set(repository, query)
        result = read_set_with_sql(
          repository,
          query.model,
          query.fields,
          query_read_statement(query),
          query.parameters,
          query.reload?
        )
        result.map do |row|
          if row.is_a? Array
            hash = {}
            query.fields.each { |prop| hash[prop.name] = '' }
            index = 0
            hash.each do |key, _|
              hash[key] = row[index]
              index += 1
            end
            row = hash
          end
          LazyMapper.const_get(query.model.to_s).new(row) if row.is_a? Hash
        end
      end

      def update(_repository, resource)
        dirty_attributes = resource.dirty_attributes

        return false if dirty_attributes.empty?

        key = resource.class.key(name)

        statement = update_statement(resource.class, dirty_attributes, key)
        bind_values = dirty_attributes.map { |p| resource.instance_variable_get(p.instance_variable_name) }
        key.each { |p| bind_values << resource.instance_variable_get(p.instance_variable_name) }

        execute(statement, *bind_values).to_i == 1
      end

      def delete(_repository, resource)
        key = resource.class.key(name)

        statement = delete_statement(resource.class, key)
        bind_values = key.map { |p| resource.instance_variable_get(p.instance_variable_name) }

        execute(statement, *bind_values)
        false
      end

      # Database-specific method
      def execute(statement, *args)
        with_connection do |connection|
          command = connection.create_command(statement)
          LazyMapper.logger.info(statement)
          command.execute_non_query(*args)
        end
      end

      def upgrade_model_storage(repository, model)
        table_name = model.storage_name(name)
        return model.properties(name) if create_model_storage(repository, model)

        properties = []

        model.properties(name).each do |property|
          schema_hash = property_schema_hash(property, model)
          next if field_exists?(table_name, schema_hash[:name])
          statement = alter_table_add_column_statement(table_name, schema_hash)
          execute(statement)
          properties << property
        end

        properties
      end

      def create_model_storage(_repository, model)
        return false if storage_exists?(model.storage_name(name))
        fail = false
        fail = true unless execute(create_table_statement(model))
        !fail
      end

      def destroy_model_storage(_repository, model)
        execute(drop_table_statement(model))
      end

      def count(_repository, property, query)
        parameters = query.parameters
        execute(aggregate_value_statement(:count, property, query), *parameters).affected_rows.first
      end

      def min(_respository, property, query)
        parameters = query.parameters
        execute(aggregate_value_statement(:min, property, query), *parameters).affected_rows[0]
      end

     def max(_respository, property, query)
       parameters = query.parameters
       execute(aggregate_value_statement(:max, property, query), *parameters).affected_rows[0]
     end

     def avg(_respository, property, query)
       parameters = query.parameters
       execute(aggregate_value_statement(:avg, property, query), *parameters).affected_rows[0]
     end

     def sum(_respository, property, query)
       parameters = query.parameters
       execute(aggregate_value_statement(:sum, property, query), *parameters).affected_rows[0]
     end

      protected

      def normalize_uri(uri_or_options)
        uri_or_options = Addressable::URI.parse(uri_or_options) if String === uri_or_options
        return uri_or_options.normalize if Addressable::URI === uri_or_options

        adapter = uri_or_options.delete(:adapter)
        user = uri_or_options.delete(:username)
        password = uri_or_options.delete(:password)
        host = (uri_or_options.delete(:host) || "")
        port = uri_or_options.delete(:port)
        database = uri_or_options.delete(:database)
        query = uri_or_options.to_a.map { |pair| pair.join('=') }.join('&')
        query = nil if query == ""
        Addressable::URI.new(
          scheme: adapter, user: user, password: password, host: host, port: port, path: database, query: query
        )
      end

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
            return yield(reader) if block
          ensure
            reader.close if reader
          end
        end
      end

      def with_connection(&block)
        connection = nil
        begin
          connection = create_connection
          return yield(connection) unless block == nil
        rescue => e
          LazyMapper.logger.error(e)
          raise e
        ensure
          close_connection(connection) if connection
        end
      end

      # used by find_by_sql and read_set
      def read_set_with_sql(repository, model, properties, sql, parameters, _do_reload)
        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
        Collection.new(repository, model, properties_with_indexes) do |set|
          with_connection do
            execute(sql, *parameters).affected_rows.each { |row| set << row }
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

          statement << if dirty_attributes.empty? && supports_default_values?
                         'DEFAULT VALUES'
                       else
                         <<-EOS.compress_lines
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

        def simple_select(query)
          qualify = query.links.any?
          statement = 'SELECT '

          statement << query.fields.map do |property|
            table_name = property.model.storage_name(name)
            property_to_column_name(table_name, property, qualify)
          end.join(', ')

          statement << ' FROM ' << quote_table_name(query.model.storage_name(name))
          statement
        end

        def add_conditions(query, statement)
          qualify = query.links.any?
          unless query.conditions.empty?
            statement << ' WHERE '
            statement << query.conditions.map do |operator, property, bind_value|
              table_name = property.model.storage_name(name) if property && property.respond_to?(:model)
              case operator
              when :raw      then property
              when :eql, :in then equality_operator(query, table_name, operator, property, qualify, bind_value)
              when :not      then inequality_operator(query, table_name, operator, property, qualify, bind_value)
              when :like     then "#{property_to_column_name(table_name, property, qualify)} LIKE ?"
              when :gt       then "#{property_to_column_name(table_name, property, qualify)} > ?"
              when :gte      then "#{property_to_column_name(table_name, property, qualify)} >= ?"
              when :lt       then "#{property_to_column_name(table_name, property, qualify)} < ?"
              when :lte      then "#{property_to_column_name(table_name, property, qualify)} <= ?"
              else raise "Invalid query operator: #{operator.inspect}"
              end
            end.join(' AND ')
          end
          statement
        end

        def add_order(query, statement)
          qualify = query.links.any?
          unless query.order.empty?
            parts = []
            query.order.each do |item|
              property = nil
              direction = nil

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
          statement
        end

        def query_read_statement(query)
          statement = simple_select(query)
          statement = add_conditions(query, statement)
          statement = add_order(query, statement)
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

        # Adapters that support AUTO INCREMENT fields for CREATE TABLE
        # statements should overwrite this to return true
        def supports_serial?
          false
        end

        def alter_table_add_column_statement(table_name, schema_hash)
          "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{property_schema_statement(schema_hash)}"
        end

        def create_table_statement(model)
          statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("
          statement << model.properties(name).collect { |p| property_schema_statement(property_schema_hash(p, model)) } * ', '

          if (key = model.key(name)).any?
            statement << ", PRIMARY KEY(#{key.collect { |p| quote_column_name(p.field(name)) } * ', '})"
          end

          statement << ')'
          statement.compress_lines
        end

        def drop_table_statement(model)
          "DROP TABLE IF EXISTS #{model.storage_name(name)}"
        end

        def property_schema_hash(property, _model)
          schema = self.class.type_map[property.type].merge(name: property.field(name))
          schema[:size] = property.length if property.type == String
          schema[:serial?] = property.serial?
          schema
        end

        def property_schema_statement(schema)
          statement = quote_column_name(schema[:name])
          statement << " #{schema[:primitive]}"
          statement << "(#{quote_column_value(schema[:size])})" if schema[:size]
          statement
        end

        # TODO: move to dm-more/dm-migrations
        def relationship_schema_hash(relationship)
          identifier, relationship = relationship

          self.class.type_map[Integer].merge(name: "#{identifier}_id") if identifier == relationship.name
        end

        # TODO: move to dm-more/dm-migrations
        def relationship_schema_statement(hash)
          property_schema_statement(hash) unless hash.nil?
        end

        def aggregate_value_statement(aggregate_function, property, query)
          qualify      = query.links.any?
          storage_name = query.model.storage_name(query.repository.name)
          column_name  = aggregate_function == :count && property.nil? ? '*' : property_to_column_name(storage_name, property, qualify)

          function_name = case aggregate_function
                          when :count then 'COUNT'
                          when :min   then 'MIN'
                          when :max   then 'MAX'
                          when :avg   then 'AVG'
                          when :sum   then 'SUM'
                          else raise "Invalid aggregate function: #{aggregate_function.inspect}"
                          end

          statement = "SELECT #{function_name}(#{column_name})"
          statement << ' FROM ' << quote_table_name(storage_name)

          statement =  add_conditions(query, statement)

          statement << " LIMIT #{query.limit}" if query.limit
          statement << " OFFSET #{query.offset}" if query.offset && query.offset > 0

          statement
        rescue => e
          LazyMapper.logger.error("QUERY INVALID: #{query.inspect} (#{e})")
          raise e
        end
      end
      include SQL
    end
  end
end
