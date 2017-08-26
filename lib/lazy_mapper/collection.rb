require 'forwardable'
module LazyMapper
  class Collection < LazyArray
    attr_reader :repository

    def reload(options = {})
      query = Query.new(@repository, @model, keys.merge(fields: @key_properties))
      query.update(options.merge(reload: true))
      @repository.adapter.read_set(@repository, query)
    end

    private

    def initialize(repository, model, properties_with_indexes, &loader)
      raise ArgumentError, "+repository+ must be a LazyMapper::Repository, but was #{repository.class}", caller unless repository.is_a?(Repository)
      raise ArgumentError, "+model+ is a #{model.class}, but is not a type of Resource", caller                 unless model < Model

      @repository              = repository
      @model                   = model
      @properties_with_indexes = properties_with_indexes

      super()
      load_with(&loader)

      if (@key_properties = @model.key(@repository.name)).all? { |key| @properties_with_indexes.include?(key) }
        @key_property_indexes = @properties_with_indexes.values_at(*@key_properties)
      end
    end

    def keys
      entry_keys = @array.map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property, values|
        keys[property] = values.size == 1 ? values[0] : values
      end
      keys
    end
  end
end
