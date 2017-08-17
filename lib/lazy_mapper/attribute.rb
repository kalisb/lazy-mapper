require 'date'
require 'time'
require 'bigdecimal'

module LazyMapper

  class Attribute

    # NOTE: check is only for psql, so maybe the postgres adapter should
    # define its own property options. currently it will produce a warning tho
    # since PROPERTY_OPTIONS is a constant
    #
    # NOTE: PLEASE update PROPERTY_OPTIONS in LazyMapper::Type when updating
    # them here
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :unique_index, :check, :ordinal, :auto_validation,
      :validates, :unique, :lock, :track, :scale, :precision
    ]

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

    VISIBILITY_OPTIONS = [ :public, :protected, :private ]

    DEFAULT_LENGTH    = 50
    DEFAULT_SCALE     = 10
    DEFAULT_PRECISION = 0

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

    # Returns whether or not the property is "serial" (auto-incrementing)
    #
    # @return <TrueClass, FalseClass> whether or not the property is "serial"
    #-
    # @api public
    def serial?
      @serial
    end

    # Returns whether or not the property can accept 'nil' as it's value
    #
    # @return <TrueClass, FalseClass> whether or not the property can accept 'nil'
    #-
    # @api public
    def nullable?
      @nullable
    end

    def lock?
      @lock
    end

    def custom?
      @custom
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

      # TODO: change Integer to be used internally once most in-the-wild code
      # is updated to use Integer for properties instead of Fixnum, or before
      # DM 1.0, whichever comes first.
      if Fixnum == type
        # It was decided that Integer is a more expressively names class to
        # use instead of Fixnum.  Fixnum only represents smaller numbers,
        # so there was some confusion over whether or not it would also
        # work with Bignum too (it will).  Any Integer, which includes
        # Fixnum and Bignum, can be stored in this property.
        warn 'Fixnum properties are deprecated.  Please use Integer instead'
      elsif Integer == type
        # XXX: ignore this for now :) We still use Fixnum internally
        # until every DO driver is updated to handle Integer natively.
        type = Fixnum
      end

      @model                  = model
      @name                   = name.to_s.sub(/\?$/, '').to_sym
      @type                   = type
      @options                = @custom ? @type.options.merge(options) : options
      @instance_variable_name = "@#{@name}"

      # TODO: This default should move to a LazyMapper::Types::Text
      # Custom-Type and out of Property.
      @primitive = @options.fetch(:primitive, @type.respond_to?(:primitive) ? @type.primitive : @type)

      @getter   = TrueClass == @primitive ? "#{@name}?".to_sym : @name
      @lock     = @options.fetch(:lock,     false)
      @serial   = @options.fetch(:serial,   false)
      @key      = @options.fetch(:key,      @serial || false)
      @default  = @options.fetch(:default,  nil)
      @nullable = @options.fetch(:nullable, @key == false && @default.nil?)
      @index    = @options.fetch(:index,    false)
      @unique_index = @options.fetch(:unique_index, false)

      @lazy     = @options.fetch(:lazy,     @type.respond_to?(:lazy) ? @type.lazy : false) && !@key

      # assign attributes per-type
      if String == @primitive || Class == @primitive
        @length = @options.fetch(:length, @options.fetch(:size, DEFAULT_LENGTH))
      elsif BigDecimal == @primitive || Float == @primitive
        @scale     = @options.fetch(:scale,     DEFAULT_SCALE)
        @precision = @options.fetch(:precision, DEFAULT_PRECISION)
      end

      determine_visibility

      create_getter
      create_setter

      @model.auto_generate_validations(self) if @model.respond_to?(:auto_generate_validations)
      @model.property_serialization_setup(self) if @model.respond_to?(:property_serialization_setup)

    end

    def determine_visibility # :nodoc:
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
      @writer_visibility = :protected if @options[:protected]
      @writer_visibility = :private   if @options[:private]
      raise ArgumentError, "property visibility must be :public, :protected, or :private" unless VISIBILITY_OPTIONS.include?(@reader_visibility) && VISIBILITY_OPTIONS.include?(@writer_visibility)
    end

    # defines the getter for the property
    def create_getter
      @model.class_eval <<-EOS, __FILE__, __LINE__
        #{reader_visibility}
        def #{@getter}
          attribute_get(#{name.inspect})
        end
      EOS

      if @primitive == TrueClass && !@model.instance_methods.include?(@name.to_s)
        @model.class_eval <<-EOS, __FILE__, __LINE__
          #{reader_visibility}
          alias #{@name} #{@getter}
        EOS
      end
    end

    # defines the setter for the property
    def create_setter
      @model.class_eval <<-EOS, __FILE__, __LINE__
        #{writer_visibility}
        def #{name}=(value)
          attribute_set(#{name.inspect}, value)
        end
      EOS
    end
  end
end
