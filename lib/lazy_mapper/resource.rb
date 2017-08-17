require 'set'

module LazyMapper

  module Resource

    def self.new(default_name, &b)
      x = Class.new
      x.send(:include, self)
      x.instance_variable_set(:@storage_names, Hash.new { |h,k| h[k] = repository(k).adapter.resource_naming_convention.call(default_name) })
      x.instance_eval(&b)
      x
    end

    @@descendents = Set.new

    # +----------------------
    # Resource module methods

    def self.included(model)
      model.extend Model
      model.extend ClassMethods
      @@descendents << model
    end

    ##
    # Return all classes that include the LazyMapper::Resource module
    #
    # @return <Set> a set containing the including classes
    # -
    # @api semipublic
    def self.descendents
      @@descendents
    end

    # +---------------
    # Instance methods

    attr_accessor :collection

    ##
    # returns the value of the attribute, invoking defaults if necessary
    #
    # @param <Symbol> name attribute to lookup
    # @return <Types> the value stored at that given attribute, nil if none, and default if necessary
    def attribute_get(name)
      property  = self.class.properties(repository.name)[name]
      ivar_name = property.instance_variable_name

      unless new_record? || instance_variable_defined?(ivar_name)
        property.lazy? ? lazy_load(name) : lazy_load(self.class.properties(repository.name).reject {|p| instance_variable_defined?(p.instance_variable_name) || p.lazy? })
      end

      value = instance_variable_get(ivar_name)

      if value.nil? && new_record? && !property.options[:default].nil?
        value = property.default_for(self)
      end

      value
    end

    ##
    # sets the value of the attribute, marks the attribute as dirty so that it may be saved
    #
    # @param <Symbol> name property to set
    # @param <Type> value value to store at that location
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

    alias == eql?

    def inspect
      attrs = attributes.inject([]) {|s,(k,v)| s << "#{k}=#{v.inspect}"}
      "#<#{self.class.name} #{attrs.join(" ")}>"
    end

    def pretty_print(pp)
      attrs = attributes.inject([]) {|s,(k,v)| s << [k,v]}
      pp.group(1, "#<#{self.class.name}", ">") do
        pp.breakable
        pp.seplist(attrs) do |k_v|
          pp.text k_v[0].to_s
          pp.text " = "
          pp.pp k_v[1]
        end
      end
    end

    ##
    #
    # @return <Repository> the respository this resource belongs to in the context of a collection OR in the class's context
    def repository
      @collection ? @collection.repository : self.class.repository
    end

    def child_associations
      @child_associations ||= []
    end

    def parent_associations
      @parent_associations ||= []
    end


    ##
    # default id method to return the resource id when there is a
    # single key, and the model was defined with a primary key named
    # something other than id
    #
    # @return <Array[Key], Key> key object
    def id
      key = self.key
      key.first if key.size == 1
    end

    # FIXME: should this take a repository_name argument
    def key
      key = []
      self.class.key(repository.name).each do |property|
        value = instance_variable_get(property.instance_variable_name)
        key << value
      end
      key
    end

    def readonly!
      @readonly = true
    end

    def readonly?
      @readonly == true
    end

    ##
    # save the instance to the data-store
    #
    # @return <True, False> results of the save
    # @see LazyMapper::Repository#save
    def save
      new_record? ? create : update
    end

    ##
    # destroy the instance, remove it from the repository
    #
    # @return <True, False> results of the destruction
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

    def shadow_attribute_get(name)
      instance_variable_get("@shadow_#{name}")
    end

    def reload
      @collection.reload(:fields => loaded_attributes)
      (parent_associations + child_associations).each { |association| association.reload! }
      self
    end
    alias reload! reload

    def reload_attributes(*attributes)
      @collection.reload(:fields => attributes)
      self
    end

    ##
    # Returns <tt>true</tt> if this model hasn't been saved to the database,
    # <tt>false</tt> otherwise.
    #
    # @return <TrueClass> if this model has been saved to the database
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
      values_hash.each_pair do |k,v|
        setter = "#{k.to_s.sub(/\?\z/, '')}="
        send(setter, v) if self.respond_to?(setter)
      end
    end

    # Updates attributes and saves model
    #
    # @param attributes<Hash> Attributes to be updated
    # @param keys<Symbol, String, Array> keys of Hash to update (others won't be updated)
    #
    # @return <TrueClass, FalseClass> if model got saved or not
    #-
    # @api public
    def update_attributes(hash, *update_only)
      raise 'Update takes a hash as first parameter' unless hash.is_a?(Hash)
      loop_thru = update_only.empty? ? hash.keys : update_only
      loop_thru.each {|attr|  send("#{attr}=", hash[attr])}
      save
    end

    ##
    # Produce a new Transaction for the class of this Resource
    #
    # @return <LazyMapper::Adapters::Transaction
    #   a new LazyMapper::Adapters::Transaction with all LazyMapper::Repositories
    #   of the class of this LazyMapper::Resource added.
    #-
    # @api public
    #
    # TODO: move to dm-more/dm-transactions
    def transaction(&block)
      self.class.transaction(&block)
    end

    private

    def create
      repository.save(self)
    end

    def update
      repository.save(self)
    end

    def initialize(*args) # :nodoc:
      validate_resource
      initialize_with_attributes(*args) unless args.empty?
    end

    def initialize_with_attributes(details) # :nodoc:
      self.attributes = details
    end

    def validate_resource # :nodoc:
      if self.class.properties.empty? && self.class.relationships.empty?
        raise IncompleteResourceError, 'Resources must have at least one property or relationship to be initialized.'
      end

      if self.class.properties.key.empty?
        raise IncompleteResourceError, 'Resources must have a key.'
      end
    end

    def lazy_load(name)
      return unless @collection
      @collection.reload(:fields => self.class.properties(repository.name).lazy_load_context(name))
    end

    def private_attributes
      pairs = {}

      self.class.properties(repository.name).each do |property|
        pairs[property.name] = send(property.getter)
      end

      pairs
    end

    def private_attributes=(values_hash)
      values_hash.each_pair do |k,v|
        setter = "#{k.to_s.sub(/\?\z/, '')}="
        send(setter, v) if respond_to?(setter)
      end
    end

    module ClassMethods
      def self.extended(model)
        model.instance_variable_set(:@storage_names, Hash.new { |h,k| h[k] = repository(k).adapter.resource_naming_convention.call(model.instance_eval do default_storage_name end) })
        model.instance_variable_set(:@properties,    Hash.new { |h,k| h[k] = k == Repository.default_name ? PropertySet.new : h[Repository.default_name].dup })
      end

      def inherited(target)
        target.instance_variable_set(:@storage_names, @storage_names.dup)
        target.instance_variable_set(:@properties, Hash.new { |h,k| h[k] = k == Repository.default_name ? self.properties(Repository.default_name).dup(target) : h[Repository.default_name].dup })
        if @relationships
          duped_relationships = {}; @relationships.each_pair{ |repos, rels| duped_relationships[repos] = rels.dup}
          target.instance_variable_set(:@relationships, duped_relationships)
        end
      end

      ##
      # Get the repository with a given name, or the default one for the current
      # context, or the default one for this class.
      #
      # @param name<Symbol>   the name of the repository wanted
      # @param block<Block>   block to execute with the fetched repository as parameter
      #
      # @return <Object, LazyMapper::Respository> whatever the block returns,
      #   if given a block, otherwise the requested repository.
      #-
      # @api public
      def repository(name = nil, &block)
        #
        # There has been a couple of different strategies here, but me (zond) and dkubb are at least
        # united in the concept of explicitness over implicitness. That is - the explicit wish of the
        # caller (+name+) should be given more priority than the implicit wish of the caller (Repository.context.last).
        #
        LazyMapper.repository(*Array(name || (Repository.context.last ? nil : default_repository_name)), &block)
      end

      ##
      # the name of the storage recepticle for this resource.  IE. table name, for database stores
      #
      # @return <String> the storage name (IE table name, for database stores) associated with this resource in the given repository
      def storage_name(repository_name = default_repository_name)
        @storage_names[repository_name]
      end

      ##
      # the names of the storage recepticles for this resource across all repositories
      #
      # @return <Hash(Symbol => String)> All available names of storage recepticles
      def storage_names
        @storage_names
      end

      ##
      # defines a property on the resource
      #
      # @param <Symbol> name the name for which to call this property
      # @param <Type> type the type to define this property ass
      # @param <Hash(Symbol => String)> options a hash of available options
      # @see LazyMapper::Property
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
        # TODO Is this right or should we add the lazy contexts to all
        # repositories?
        if property.lazy?
          context = options.fetch(:lazy, :default)
          context = :default if context == true
          Array(context).each do |item|
            @properties[repository.name].lazy_context(item) << name
          end
        end
		
        property
      end

      def repositories
        [repository] + @properties.keys.collect do |repository_name| LazyMapper.repository(repository_name) end
      end

      def properties(repository_name = default_repository_name)
        @properties[repository_name]
      end

      def key(repository_name = default_repository_name)
        @properties[repository_name].key
      end

      ##
      #
      # @see Repository#get
      def get(*key)
        repository.get(self, key)
      end

      ##
      #
      # @see Resource#get
      # @raise <ObjectNotFoundError> "could not find .... with key: ...."
      def [](key)
        get(key) || raise(ObjectNotFoundError, "Could not find #{self.name} with key: #{key.inspect}")
      end

      ##
      #
      # @see Repository#all
      def all(options = {})
        if Hash === options && options.has_key?(:repository)
          repository(options[:repository]).all(self, options)
        else
          repository.all(self, options)
        end
      end

      ##
      #
      # @see Repository#first
      def first(options = {})
        if Hash === options && options.has_key?(:repository)
          repository(options[:repository]).first(self, options)
        else
          repository.first(self, options)
        end
      end

      # Count results (given the conditions)
      def count(*args)
        with_repository_and_property(*args) do |repository,property,options|
           repository.count(self, property, options)
        end
      end

      def min(*args)
       with_repository_and_property(*args) do |repository,property,options|
         check_property_is_number(property)
         repository.min(self, property, options)
       end
     end

     def max(*args)
        with_repository_and_property(*args) do |repository,property,options|
          check_property_is_number(property)
          repository.max(self, property, options)
        end
    end

    def avg(*args)
        with_repository_and_property(*args) do |repository,property,options|
          check_property_is_number(property)
          repository.avg(self, property, options)
        end
    end

    def sum(*args)
       with_repository_and_property(*args) do |repository,property,options|
         check_property_is_number(property)
         repository.sum(self, property, options)
       end
    end

      ##
      # Create an instance of Resource with the given attributes
      #
      # @param <Hash(Symbol => Object)> attributes hash of attributes to set
      def create(attributes = {})
        resource = allocate
        resource.send(:initialize_with_attributes, attributes)
        resource.save
        resource
      end

      ##
      # Dangerous version of #create.  Raises if there is a failure
      #
      # @see LazyMapper::Resource#create
      # @param <Hash(Symbol => Object)> attributes hash of attributes to set
      # @raise <PersistenceError> The resource could not be saved
      def create!(attributes = {})
        resource = create(attributes)
        raise PersistenceError, "Resource not saved: :new_record => #{resource.new_record?}, :dirty_attributes => #{resource.dirty_attributes.inspect}" if resource.new_record?
        resource
      end

      # TODO SPEC
      def copy(source, destination, options = {})
        repository(destination) do
          repository(source).all(self, options).each do |resource|
            self.create(resource)
          end
        end
      end

      #
      # Produce a new Transaction for this Resource class
      #
      # @return <LazyMapper::Adapters::Transaction
      #   a new LazyMapper::Adapters::Transaction with all LazyMapper::Repositories
      #   of the class of this LazyMapper::Resource added.
      #-
      # @api public
      #
      # TODO: move to dm-more/dm-transactions
      def transaction(&block)
        LazyMapper::Transaction.new(self, &block)
      end

      def storage_exists?(repository_name = default_repository_name)
        repository(repository_name).storage_exists?(storage_name(repository_name))
      end

      # TODO: remove this alias
      alias exists? storage_exists?

      private

      def default_storage_name
        self.name
      end

      def default_repository_name
        Repository.default_name
      end

      def with_repository_and_property(*args, &block)
        options       = Hash === args.last ? args.pop : {}
        property_name = args.shift

        repository(*Array(options[:repository])) do |repository|
          property = properties(repository.name)[property_name] if property_name
          yield repository, property, options
        end
      end

    end # module ClassMethods
  end # module Resource
end # module LazyMapper
