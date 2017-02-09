require 'date'
require 'time'
require 'bigdecimal'

module LazyMapper

  # = Properties
  # Properties for a model are not derived from a database structure, but
  # instead explicitly declared inside your model class definitions. These
  # properties then map (or, if using automigrate, generate) fields in your
  # repository/database.
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
  # Properties can be declared as primary or natural keys on a table.
  # You should a property as the primary key of the table:
  #
  class Property

    PROPERTY_OPTIONS = [ :key, :unique,]

    # FIXME: can we pull the keys from
    # LazyMapper::Adapters::DataObjectsAdapter::TYPES
    # for this?
    TYPES = [
      TrueClass,
      String,
      Float,
      Fixnum,
      Integer,
      BigDecimal,
      DateTime,
      Date,
      Time,
      Object,
      Class,
    ]

    attr_reader :primitive, :model, :name, :instance_variable_name,
      :type, :reader_visibility, :writer_visibility, :getter, :options,
      :default, :precision, :scale

    # Supplies the field in the data-store which the property corresponds to
    #
    # @return <String> name of field in data-store
    # -
    # @api semi-public
    def field(*args)
      @options.fetch(:field, repository(*args).adapter.field_naming_convention.call(name))
    end

    def unique
      @unique ||= @options.fetch(:unique, @serial || @key || false)
    end

    def repository(*args)
      @model.repository(*args)
    end

    def hash
      if @custom && !@bound
        @type.bind(self)
        @bound = true
      end

      return @model.hash + @name.hash
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

    def index
      @index
    end

    def unique_index
      @unique_index
    end

    # Returns whether or not the property is to be lazy-loaded
    #
    # @return <TrueClass, FalseClass> whether or not the property is to be
    #   lazy-loaded
    # -
    # @api public
    def lazy?
      @lazy
    end


    # Returns whether or not the property is a key or a part of a key
    #
    # @return <TrueClass, FalseClass> whether the property is a key or a part of
    #   a key
    #-
    # @api public
    def key?
      @key
    end

    # Provides a standardized getter method for the property
    #
    # @raise <ArgumentError> "+resource+ should be a LazyMapper::Resource, but was ...."
    #-
    # @api private
    def get(resource)
      raise ArgumentError, "+resource+ should be a LazyMapper::Resource, but was #{resource.class}" unless Resource === resource
      resource.attribute_get(@name)
    end

    # Provides a standardized setter method for the property
    #
    # @raise <ArgumentError> "+resource+ should be a LazyMapper::Resource, but was ...."
    #-
    # @api private
    def set(resource, value)
      raise ArgumentError, "+resource+ should be a LazyMapper::Resource, but was #{resource.class}" unless Resource === resource
      resource.attribute_set(@name, value)
    end

    # typecasts values into a primitive
    #
    # @return <TrueClass, String, Float, Integer, BigDecimal, DateTime, Date, Time
    #   Class> the primitive data-type, defaults to TrueClass
    #-
    # @private
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

    def default_for(resource)
      @default.respond_to?(:call) ? @default.call(resource, self) : @default
    end

    def inspect
      "#<Property:#{@model}:#{@name}>"
    end

    private

    def initialize(model, name, type, options = {})
      raise ArgumentError, "+model+ is a #{model.class}, but is not a type of Resource"                 unless Resource > model
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}"                           unless Symbol === name
      raise ArgumentError, "+type+ was #{type.inspect}, which is not a supported type: #{TYPES * ', '}" unless TYPES.include?(type) || (LazyMapper::Type > type && TYPES.include?(type.primitive))

      if (unknown_options = options.keys - PROPERTY_OPTIONS).any?
        raise ArgumentError, "+options+ contained unknown keys: #{unknown_options * ', '}"
      end

      @model                  = model
      @name                   = name.to_s.sub(/\?$/, '').to_sym
      @type                   = type
      @options                = options
      @instance_variable_name = "@#{@name}"

      # TODO: This default should move to a LazyMapper::Types::Text
      # Custom-Type and out of Property.
      @primitive = @options.fetch(:primitive, @type.respond_to?(:primitive) ? @type.primitive : @type)

      @getter   = TrueClass == @primitive ? "#{@name}?".to_sym : @name
      @key      = @options.fetch(:key,      @serial || false)

      create_getter
      create_setter

      @model.auto_generate_validations(self) if @model.respond_to?(:auto_generate_validations)
      @model.property_serialization_setup(self) if @model.respond_to?(:property_serialization_setup)

    end

    # defines the getter for the property
    def create_getter
      @model.define_singleton_method("#{@getter}") do
        attr_accessor("#{@name.inspect}")
        attribute_get("#{@name}")
      end
    end

    # defines the setter for the property
    def create_setter
      @model.define_singleton_method("#{name}=") do |value|
        attribute_set("#{name.inspect}", value)
      end
    end
  end # class Property
end # module LazyMapper
