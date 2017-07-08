require 'date'
require 'time'
require 'bigdecimal'

module LazyMapper

  # = Properties
  # Properties for a model are not derived from a database structure, but
  # instead explicitly declared inside your model class definitions. These
  # properties then map fields in your # repository/database.
  #
  # == Declaring Properties
  # Inside your class, you call the property method for each property you want
  # to add. The only two required arguments are the name and type, everything
  # else is optional.
  #
  # == Lazy Loading
  # By default, some properties are not loaded when an object is fetched in
  # LazyMapper. These lazily loaded properties are fetched on demand when their
  # accessor is called for the first time (as it is often unnecessary to
  # instantiate -every- property -every- time an object is loaded).
  #
  # == Keys
  # Properties can be declared as primary keys on a table.
  #
  class Property

    PROPERTY_OPTIONS = [ :key, :lazy ]

    attr_reader :model, :name, :type, :options, :length, :instance_variable_name

    # Supplies the field in the data-store which the property corresponds to
    def field(*args)
      @options.fetch(:field, repository(*args).adapter.field_naming_convention.call(name))
    end

    def repository(*args)
      @model.repository(*args)
    end

    def eql?(o)
      if o.is_a?(Property)
        return o.model == @model && o.name == @name
      else
        return false
      end
    end

    def length
      @length.is_a?(Range) ? @length.max : @length
    end
    alias size length


    # Returns whether or not the property is to be lazy-loaded
    def lazy?
      @lazy
    end


    # Returns whether or not the property is a key or a part of a key
    def key?
      @key
    end

    def default_for(resource)
      @default.respond_to?(:call) ? @default.call(resource, self) : @default
    end

    # Provides a standardized getter method for the property
    def get(resource)
      lazy_load(resource)
      raise ArgumentError, "+resource+ should be a LazyMapper::Resource, but was #{resource.class}" unless Resource === resource
      resource.attribute_get(@name)
    end

    # Provides a standardized setter method for the property
    def set(resource, value)
      lazy_load(resource)
      raise ArgumentError, "+resource+ should be a LazyMapper::Resource, but was #{resource.class}" unless Resource === resource
      resource.attribute_set(@name, value)
    end

    # Loads lazy columns when get or set is called.
    def lazy_load(resource)
      # TODO: refactor this section
      contexts = if lazy?
        name
      else
        model.properties(resource.repository.name).reject do |property|
          property.lazy? || resource.attribute_loaded?(property.name)
        end
      end
      resource.send(:lazy_load, contexts)
    end

    # typecasts values into a primitive
    def typecast(value)
      return value if type === value || (value.nil? && type != TrueClass)

      if    type == TrueClass  then %w[ true 1 t ].include?(value.to_s.downcase)
      elsif type == String     then value.to_s
      elsif type == Float      then value.to_f
      elsif type == Fixnum     then value.to_i
      elsif type == BigDecimal then BigDecimal(value.to_s)
      elsif type == DateTime   then DateTime.parse(value.to_s)
      elsif type == Date       then Date.parse(value.to_s)
      elsif type == Time       then Time.parse(value.to_s)
      elsif type == Class      then find_const(value)
      end
    end

    private

    def initialize(model, name, type, options = {})
      raise ArgumentError, "+model+ is a #{model.class}, but is not a type of Resource"                 unless Resource > model
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}"                           unless Symbol === name

      if (unknown_options = options.keys - PROPERTY_OPTIONS).any?
        raise ArgumentError, "+options+ contained unknown keys: #{unknown_options * ', '}"
      end

      @model                  = model
      @name                   = name.to_s.sub(/\?$/, '').to_sym
      @type                   = type
      @options                = options
      @instance_variable_name = "@#{@name}"

      # Custom-Type and out of Property.
      @primitive = @options.fetch(:primitive, @type.respond_to?(:primitive) ? @type.primitive : @type)

      @getter   = TrueClass == @primitive ? "#{@name}?".to_sym : @name
      @key      = @options.fetch(:key,      @serial || false)
      @lazy = @options.fetch(:lazy, @type.respond_to?(:lazy) ? @type.lazy : false) && !@key

      create_getter
      create_setter

      @model.auto_generate_validations(self) if @model.respond_to?(:auto_generate_validations)
      @model.property_serialization_setup(self) if @model.respond_to?(:property_serialization_setup)

    end


    # defines the getter for the property
    def create_getter
      @model.class_eval <<-EOS, __FILE__, __LINE__
        def #{@getter}
          #attr_accessor("#{@name.inspect}")
          attribute_get(#{name.inspect})
        end
      EOS

      if @primitive == TrueClass && !@model.instance_methods.include?(@name.to_s)
        @model.class_eval <<-EOS, __FILE__, __LINE__
          alias #{@name} #{@getter}
        EOS
      end
    end

    # defines the setter for the property
    def create_setter
      @model.class_eval <<-EOS, __FILE__, __LINE__
        def #{name}=(value)
          attribute_set(#{name.inspect}, value)
        end
      EOS
    end
  end # class Property
end # module LazyMapper
