require 'set'
module LazyMapper
  module ClassMethods
    def self.extended(model)
      model.instance_variable_set(:@storage_names, Hash.new { |h, k| h[k] = repository(k).adapter.resource_naming_convention.call(model.instance_eval { default_storage_name } ) })
      model.instance_variable_set(:@properties,    Hash.new { |h, k| h[k] = k == Repository.default_name ? PropertySet.new : h[Repository.default_name].dup })
    end

    ##
    # Get the repository with a given name, or the default one for the current
    # context, or the default one for this class.
    #
    def repository(name = nil, &block)
      LazyMapper.repository(*Array(name || (Repository.context.last ? nil : default_repository_name)), &block)
    end

    ##
    # the name of the storage recepticle for this resource.
    #
    def storage_name(repository_name = default_repository_name)
      @storage_names[repository_name]
    end

    ##
    # the names of the storage recepticles for this resource across all repositories
    #
    def storage_names
      @storage_names
    end

    ##
    # defines a property on the resource
    #
    def property(name, type, options = {})
      property = Property.new(self, name, type, options)
      @properties[repository.name] << property

      # Add property to the other mappings as well if this is for the default
      # repository.
      if repository.name == default_repository_name
        @properties.each_pair do |repository_name, properties|
          next if repository_name == default_repository_name
          properties << property
        end
      end

      # Add the property to the lazy_loads set for this resources repository
      # only.
      #
      if property.lazy?
        context = options.fetch(:lazy, :default)
        context = :default if context == true

        Array(context).each do |item|
          @properties[repository.name].lazy_context(item) << name
        end
      end

      property
    end

    def properties(repository_name = default_repository_name)
      @properties[repository_name]
    end

    def key(repository_name = default_repository_name)
      @properties[repository_name].key
    end

    def where(options = {})
      releation = LazyMapper::Relation.new(repository, self, options)
      releation
    end

    ##
    # Create an instance of Model with the given attributes
    ##
    def create(attributes = {})
      resource = self.new(attributes)
      attributes.each do |key, value|
        resource.send(:instance_variable_set, "@#{key}", value)
      end
      resource.save
      resource
    end

    ##
    #
    # @see Repository#all
    def all(options = {})
      if Hash === options && options.key?(:repository)
        repository(options[:repository]).all(self, options)
      else
        repository.all(self, options)
      end
    end

    def order(options = {})
      options_map = {order: options}
      repository.all(self, options_map)
    end

    ##
    #
    # @see Repository#first
    def first(options = {})
      if Hash === options && options.key?(:repository)
        repository(options[:repository]).first(self, options)
      else
        repository.first(self, options)
      end
    end

    # Count results (given the conditions)
    def count(*args)
      with_repository_and_property(*args) do |repository, property, options|
        repository.count(self, property, options)
      end
    end

    def limit(options = {})
      options_map = {limit: options}
      releation = LazyMapper::Relation.new(repository, self, options_map)
      releation
    end

    def offset(options = {})
      options_map = {offset: options}
      releation = LazyMapper::Relation.new(repository, self, options_map)
      releation
    end

    def min(*args)
      with_repository_and_property(*args) do |repository, property, options|
        repository.min(self, property, options)
      end
    end

   def max(*args)
     with_repository_and_property(*args) do |repository, property, options|
       repository.max(self, property, options)
     end
   end

  def avg(*args)
    with_repository_and_property(*args) do |repository, property, options|
      repository.avg(self, property, options)
    end
  end

  def sum(*args)
    with_repository_and_property(*args) do |repository, property, options|
      repository.sum(self, property, options)
    end
  end

  def storage_exists?(repository_name = default_repository_name)
    repository(repository_name).storage_exists?(storage_name(repository_name))
  end

    private
    def default_storage_name
      self.name
    end

    def default_repository_name
      Repository.default_name
    end

    def with_repository_and_property(*args, &block)
      options = Hash === args.last ? args.pop : {}
      property_name = args.shift

      repository(*Array(options[:repository])) do |repository|
        property = properties(repository.name)[property_name] if property_name
        block.yield repository, property, options if block_given?
      end
    end
  end

  class Model
    ##
    # Add basic class methods
    ##
    def self.inherited(model)
      model.extend LazyMapper::ClassMethods
    end

    # +---------------
    # Instance methods

    attr_accessor :collection

    ##
    # returns the value of the attribute, invoking defaults if necessary
    def attribute_get(name)
      property  = self.class.properties(repository.name)[name]
      ivar_name = property.instance_variable_name

      unless new_record? || instance_variable_defined?(ivar_name)
        property.lazy? ? lazy_load(name) : lazy_load(self.class.properties(repository.name).reject { |p| instance_variable_defined?(p.instance_variable_name) || p.lazy? })
      end

      value = instance_variable_get(ivar_name)

      if value.nil? && new_record? && !property.options[:default].nil?
        value = property.default_for(self)
      end

      value
    end

    ##
    # sets the value of the attribute, marks the attribute as dirty so that it may be saved
    def attribute_set(name, value)
      property  = self.class.properties(repository.name)[name]
      ivar_name = property.instance_variable_name

      old_value = instance_variable_get(ivar_name)
      new_value = property.typecast(value)

      return if new_value == old_value || new_value.nil?

      dirty_attributes << property
      instance_variable_set(ivar_name, new_value)
    end

    def eql?(other)
      return true if object_id == other.object_id
      return false unless self.class === other
      attributes == other.attributes
    end

    alias_method '==', 'eql?'

    def inspect
      attrs = attributes.inject([]) { |s, (k, v)| s << "#{k}=#{v.inspect}" }
      "#<#{self.class.name} #{attrs.join(" ")}>"
    end

    def repository
      @collection ? @collection.repository : self.class.repository
    end

    def child_associations
      @child_associations ||= []
    end

    def parent_associations
      @parent_associations ||= []
    end

    def key
      key = []
      self.class.key(repository.name).each do |property|
        value = instance_variable_get(property.instance_variable_name)
        key << value
      end
      key
    end

    ##
    # save the instance to the data-store
    def save
      new_record? ? create : update
    end

    ##
    # destroy the instance, remove it from the repository
    def destroy
      repository.destroy(self)
    end

    def attribute_loaded?(name)
      property = self.class.properties(repository.name)[name]
      instance_variable_defined?(property.instance_variable_name)
    end

    def loaded_attributes
      names = []
      self.class.properties(repository.name).each do |property|
        names << property.name if instance_variable_defined?(property.instance_variable_name)
      end
      names
    end

    def dirty_attributes
      @dirty_attributes ||= Set.new
    end

    def dirty?
      dirty_attributes.any?
    end

    def attribute_dirty?(name)
      property = self.class.properties(repository.name)[name]
      dirty_attributes.include?(property)
    end

    def reload
      @collection.reload(fields: loaded_attributes)
      (parent_associations + child_associations).each { |association| association.reload! }
      self
    end

    def reload_attributes(*attributes)
      @collection.reload(fields: attributes)
      self
    end

    ##
    # Returns <tt>true</tt> if this model hasn't been saved to the database,
    def new_record?
      !defined?(@new_record) || @new_record
    end

    def attributes
      pairs = {}

      self.class.properties(repository.name).each do |property|
        pairs[property.name] = send(property.getter)
      end

      pairs
    end

    # Mass-assign mapped fields.
    def attributes=(values_hash)
      values_hash.each_pair do |k, v|
        setter = "#{k.to_s.sub(/\?\z/, '')}="
        send(setter, v) if self.respond_to?(setter)
      end
    end

    # Updates attributes and saves model
    def update_attributes(hash, *update_only)
      raise 'Update takes a hash as first parameter' unless hash.is_a?(Hash)
      loop_thru = update_only.empty? ? hash.keys : update_only
      loop_thru.each { |attr| send("#{attr}=", hash[attr]) }
      save
    end

    def create
      repository.save(self)
    end

    def update
      repository.save(self)
    end

    private

    def initialize(*args)
      validate_resource
      initialize_with_attributes(*args) unless args.empty?
    end

    def initialize_with_attributes(details)
      self.attributes = details
    end

    def validate_resource
      if self.class.properties.empty? && self.class.relationships.empty?
        raise IncompleteResourceError, 'Resources must have at least one property or relationship to be initialized.'
      end

      if self.class.properties.key.empty?
        raise IncompleteResourceError, 'Resources must have a key.'
      end
    end

    def lazy_load(name)
      return unless @collection
      @collection.reload(fields: self.class.properties(repository.name).lazy_load_context(name))
    end
  end
end
