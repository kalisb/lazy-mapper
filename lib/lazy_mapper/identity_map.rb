module LazyMapper
  # Tracks objects to help ensure that each object gets loaded only once.
  class IdentityMap
    attr_reader :cache
    # Get a resource from the IdentityMap
    def get(key)
      raise ArgumentError, "+key+ is not an Array, but was #{key.class}" unless Array === key

      @cache[key]
    end

    alias_method '[]', 'get'

    # Add a resource to the IdentityMap
    def set(key, resource)
      raise ArgumentError, "+key+ is not an Array, but was #{key.class}"                            unless Array === key
      raise ArgumentError, "+resource+ should be a LazyMapper::Resource, but was #{resource.class}" unless Model === resource

      @second_level_cache.set(key, resource) if @second_level_cache
      @cache[key] = resource
    end

    alias_method '[]=', 'set'

    # Remove a resource from the IdentityMap
    def delete(key)
      raise ArgumentError, "+key+ is not an Array, but was #{key.class}" unless Array === key

      @second_level_cache.delete(key) if @second_level_cache
      @cache.delete(key)
    end

    private

    def initialize(second_level_cache = nil)
      @cache = if @second_level_cache = second_level_cache
                 Hash.new { |h, key| h[key] = @second_level_cache.get(key) }
               else
                 {}
               end
    end

    def method_missing(method, *args, &block)
      cache.__send__(method, *args, &block)
    end
  end
end
