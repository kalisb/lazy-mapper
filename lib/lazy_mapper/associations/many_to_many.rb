module LazyMapper
  module Associations
    module ManyToMany
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max ]

      private

      def many_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash === options

        child_model_name  = LazyMapper::Inflection.demodulize(self.name)
        parent_model_name = options.fetch(:class_name, LazyMapper::Inflection.classify(name))

        relationship = relationships(repository.name)[name] = Relationship.new(
          name,
          repository.name,
          child_model_name,
          parent_model_name,
          options
        )

        relationship
      end

      class Proxy < BasicObject
        def save
          raise NotImplementedError
        end
      end
    end
  end
end
