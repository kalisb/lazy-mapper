module LazyMapper
  class Query
    class Direction
      attr_reader :property, :direction

      private

      def initialize(property, direction = :asc)
        raise ArgumentError, "+property+ is not a LazyMapper::Property, but was #{property.class}", caller unless Property === property
        raise ArgumentError, "+direction+ is not a Symbol, but was #{direction.class}", caller             unless Symbol   === direction

        @property  = property
        @direction = direction
      end
    end

    class Operator
      attr_reader :target, :operator

      private

      def initialize(target, operator)
        unless Symbol === operator
          raise ArgumentError, "+operator+ is not a Symbol, but was #{type.class}", caller
        end

        @target     = target
        @operator   = operator
      end
    end

    OPTIONS = [
      :reload, :offset, :limit, :order, :fields, :links, :includes, :conditions
    ]

    attr_reader :model, *OPTIONS

    def update(other)
      other = self.class.new(@repository, model, other) if Hash === other

      @model = other.model
      @reload = other.reload

      @offset = other.offset unless other.offset == 0
      @limit  = other.limit  unless other.limit.nil?

      # if self model and other model are the same, then
      # overwrite @order with other order.  If they are different
      # then set @order to the union of other order and @order,
      # with the other order taking precedence
      @order = @model == other.model ? other.order : other.order | @order

      @fields   |= other.fields
      @links    |= other.links
      @includes |= other.includes

      update_conditions(other)

      self
    end

    alias_method 'eql?', '=='

    def parameters
      parameters = []
      conditions.each do |tuple|
        next unless tuple.size == 3
        operator, _, bind_value = *tuple
        if :raw == operator
          parameters.push(*bind_value)
        else
          parameters << bind_value
        end
      end
      parameters
    end

    alias_method 'reload?', 'reload'

    private

    def initialize(repository, model, options = {})
      raise TypeError, "+repository+ must be a Repository, but is #{repository.class}" unless Repository === repository

      options.each_pair { |k, v| option[k] = v.call if v.is_a? Proc } if options.is_a? Hash

      validate_model(model)
      validate_options(options)

      @repository = repository
      @properties = model.properties(@repository.name)

      @model      = model
      @reload     = options.fetch :reload,   false
      @offset     = options.fetch :offset,   0
      @limit      = options.fetch :limit,    nil
      @order      = options.fetch :order,    []
      @fields     = options.fetch :fields,   @properties.defaults
      @links      = options.fetch :links,    []
      @includes   = options.fetch :includes, []
      @conditions = []

      # normalize order and fields
      normalize_order
      normalize_fields

      # treat all non-options as conditions
      (options.keys - OPTIONS - OPTIONS.map(&:to_s)).each do |k|
        append_condition(k, options[k])
      end
    end

    # validate the model
    def validate_model(model)
      raise ArgumentError, "+model+ must be a Class, but is #{model.class}" unless Class === model.class
      raise ArgumentError, '+model+ must include LazyMapper::Resource'      unless Model > model
    end

    # validate the options
    def validate_options(options)
      raise ArgumentError, "+options+ must be a Hash, but was #{options.class}" unless Hash === options

      # validate the reload option
      if options.key?(:reload) && options[:reload] != true && options[:reload] != false
        raise ArgumentError, "+options[:reload]+ must be true or false, but was #{options[:reload].inspect}"
      end

      # validate the offset and limit options
      ([ :offset, :limit ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, "+options[:#{attribute}]+ must be an Integer, but was #{value.class}" unless Integer === value
      end
      raise ArgumentError, '+options[:offset]+ must be greater than or equal to 0' if options.key?(:offset) && !(options[:offset] >= 0)
      raise ArgumentError, '+options[:limit]+ must be greater than or equal to 1'  if options.key?(:limit)  && !(options[:limit]  >= 1)

      # validate the order, fields, links, includes and conditions options
      ([ :order, :fields, :links, :includes, :conditions ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, "+options[:#{attribute}]+ must be an Array, but was #{value.class}" unless Array === value
        raise ArgumentError, "+options[:#{attribute}]+ cannot be empty"                          unless value.any?
      end
    end

    # normalize order elements
    def normalize_order
      @order = @order.map do |order_by|
        case order_by
        when Direction
          order_by
        when Property
          Direction.new(order_by)
        when Operator
          property = @properties[order_by.target]
          Direction.new(property, order_by.operator)
        when Symbol, String
          property = @properties[order_by]
          raise ArgumentError, "+options[:order]+ entry #{order_by} does not map to a LazyMapper::Property" if property.nil?
          Direction.new(property)
        else
          raise ArgumentError, "+options[:order]+ entry #{order_by.inspect} not supported"
        end
      end
    end

    # normalize fields
    def normalize_fields
      @fields = @fields.map do |field|
        case field
        when Property
          field
        when Symbol, String
          property = @properties[field]
          raise ArgumentError, "+options[:fields]+ entry #{field} does not map to a LazyMapper::Property" if property.nil?
          property
        else
          raise ArgumentError, "+options[:fields]+ entry #{field.inspect} not supported"
        end
      end
    end

    def append_condition(clause, bind_value)
      operator = :eql
      bind_value = bind_value.call if bind_value.is_a?(Proc)
      property = case clause
                 when Property
                   clause
                 when Operator
                   operator = clause.operator
                   if clause.target.is_a?(Symbol)
                     @properties[clause.target]
                   elsif clause.target.is_a?(Query::Path)
                     validate_query_path_links(clause.target)
                     clause.target
                   end
                 when Symbol
                   @properties[clause]
                 when String
                   if clause =~ /\w\.\w/
                     query_path = @model
                     clause.split(".").each { |piece| query_path = query_path.send(piece) }
                     append_condition(query_path, bind_value)
                     return
                   else
                     @properties[clause]
                   end
                 else
                   raise ArgumentError, "Condition type #{clause.inspect} not supported"
                 end

      raise ArgumentError, "Clause #{clause.inspect} does not map to a LazyMapper::Property" if property.nil?

      @conditions << [ operator, property, bind_value ]
    end

    def update_conditions(*)
      # build an index of conditions by the property and operator to
      # avoid nested looping
      conditions_index = Hash.new { |h, k| h[k] = {} }
      @conditions.each do |condition|
        operator, property = *condition
        next if :raw == operator
        conditions_index[property][operator] = condition
      end
    end
  end
end
