module LazyMapper
  class Repository
    @adapters = {}

    class << self
      attr_accessor :adapters
    end

    def self.context
      Thread.current[:contexts] ||= []
    end

    def self.default_name
      :default
    end

    attr_reader :name, :adapter, :type_map, :adapters

    def identity_map_get(model, key)
      identity_map(model)[key]
    end

    def identity_map_set(resource)
      identity_map(resource.class)[resource.key] = resource
    end

    def identity_map(model)
      @identity_maps[model.class] ||= IdentityMap.new
    end

    ##
    # retrieve a singular instance by query
    def first(model, options)
      query = if current_scope = model.send(:current_scope)
                current_scope.merge(options.merge(limit: 1))
              else
                Query.new(self, model, options.merge(limit: 1))
              end

      adapter.read_set(self, query).first
    end

    def count(model, property, options)
      @adapter.count(self, property, scoped_query(model, options))
    end

    def min(model, property, options)
      @adapter.min(self, property, scoped_query(model, options))
    end

   def max(model, property, options)
     @adapter.max(self, property, scoped_query(model, options))
   end

   def avg(model, property, options)
     @adapter.avg(self, property, scoped_query(model, options))
   end

   def sum(model, property, options)
     @adapter.sum(self, property, scoped_query(model, options))
   end

    ##
    # retrieve a collection of results of a query
    def all(model, options)
      query = Query.new(self, model, options)
      adapter.read_set(self, query)
    end

    ##
    # save the instance into the data-store, updating if it already exists
    def save(resource)
      resource.child_associations.each { |a| a.save }

      model = resource.class

      # set defaults for new resource
      if resource.new_record?
        model.properties(name).each do |property|
          next if resource.attribute_loaded?(property.name)
          property.set(resource, property.default_for(resource))
        end
      end

      success = false

      # save the resource if is dirty, or is a new record with a serial key
      if resource.dirty? || (resource.new_record? && model.key.any? { |p| p.serial? })
        if resource.new_record?
          if adapter.create(self, resource)
            identity_map_set(resource)
            resource.instance_variable_set(:@new_record, false)
            resource.dirty_attributes.clear
            properties_with_indexes = Hash[*model.properties.zip((0...model.properties.length).to_a).flatten]
            resource.collection = LazyMapper::Collection.new(self, model, properties_with_indexes)
            resource.collection << resource
            success = true
          end
        elsif adapter.update(self, resource)
          resource.dirty_attributes.clear
          success = true
        end
      end

      resource.parent_associations.each { |a| a.save }

      success
    end

    ##
    # removes the resource from the data-store.  The instance will remain in active-memory, but will now be marked as a new_record and it's keys will be revoked
    #
    # @param <Class> resource the resource to be destroyed
    # @return <True, False> results of the destruction
    def destroy(resource)
      if adapter.delete(self, resource)
        identity_maps[resource.class].delete(resource.key)
        resource.instance_variable_set(:@new_record, true)
        resource.dirty_attributes.clear
        resource.class.properties(name).each do |property|
          resource.dirty_attributes << property if resource.attribute_loaded?(property.name)
        end
        true
      else
        false
      end
    end

    def to_s
      "#<LazyMapper::Repository:#{@name}>"
    end

    def map(*args)
      type_map.map(*args)
    end

    def type_map
      @type_map ||= TypeMap.new(adapter.class.type_map)
    end

    ##
    #
    # @return <True, False> whether or not the data-store exists for this repo
    def storage_exists?(storage_name)
      adapter.storage_exists?(storage_name)
    end

    alias_method 'exists?', 'storage_exists?'

    private

    attr_reader :identity_maps

    def initialize(name)
      @name          = name
      @adapter       = self.class.adapters[name]
      @identity_maps = {}
    end

    def scoped_query(model, options)
      if current_scope = model.send(:current_scope)
        current_scope.merge(options)
      else
        Query.new(self, model, options)
      end
    end
  end
end
