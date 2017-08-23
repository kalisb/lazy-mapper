module LazyMapper
  module Associations
    class Relationship
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :through ]

      attr_reader :name, :repository_name, :options, :query

      def child_key
        @child_key ||= begin
          model_properties = child_model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property, property_name|
            property_name ||= "#{name}_#{parent_property.name}".to_sym
            type = parent_property.type
            model_properties[property_name] || LazyMapper.repository(repository_name) { child_model.property(property_name, type) }
          end

          PropertySet.new(child_key)
        end
      end

      def parent_key
        @parent_key ||= begin
          parent_key = if @parent_properties
                         parent_model.properties(repository_name).slice(*@parent_properties)
                       else
                         parent_model.key(repository_name)
                       end

          PropertySet.new(parent_key)
        end
      end

      def get_children(parent, options = {}, finder = :all)
        bind_values = parent_key.get(parent)
        query = child_key.to_query(bind_values)

        LazyMapper.repository(repository_name) do
          child_model.send(finder, @query.merge(options).merge(query))
        end
      end

      def get_parent(child)
        bind_values = child_key.get(child)
        return nil if bind_values.any? { |bind_value| bind_value.nil? }
        query = parent_key.to_query(bind_values)

        LazyMapper.repository(repository_name) do
          parent_model.first(@query.merge(query))
        end
      end

      def attach_parent(child, parent)
        child_key.set(child, parent && parent_key.get(parent))
      end

      def parent_model
        find_const(@parent_model_name)
      end

      def child_model
        find_const(@child_model_name)
      end

      private

      def initialize(name, repository_name, child_model_name, parent_model_name, options = {}, &loader)
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller                         unless Symbol === name
        raise ArgumentError, "+repository_name+ must be a Symbol, but was #{repository_name.class}", caller     unless Symbol === repository_name
        raise ArgumentError, "+child_model_name+ must be a String, but was #{child_model_name.class}", caller   unless String === child_model_name
        raise ArgumentError, "+parent_model_name+ must be a String, but was #{parent_model_name.class}", caller unless String === parent_model_name

        if child_properties = options[:child_key]
          raise ArgumentError, "+options[:child_key]+ must be an Array or nil, but was #{child_properties.class}", caller unless Array === child_properties
        end

        if parent_properties = options[:parent_key]
          raise ArgumentError, "+parent_properties+ must be an Array or nil, but was #{parent_properties.class}", caller unless Array === parent_properties
        end

        @name              = name
        @repository_name   = repository_name
        @child_model_name  = child_model_name
        @child_properties  = child_properties
        @query             = options.reject { |k, _| OPTIONS.include?(k) }
        @parent_model_name = parent_model_name
        @parent_properties = parent_properties
        @options           = options
        @loader            = loader
      end
    end
  end
end
