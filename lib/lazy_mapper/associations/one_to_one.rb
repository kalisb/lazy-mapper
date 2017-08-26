module LazyMapper
  module Associations
    module OneToOne
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :remote_name ]

      private

      def one_to_one(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller     unless Symbol === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        relationship = relationships(repository.name)[name] = Relationship.new(
          LazyMapper::Inflection.underscore(LazyMapper::Inflection.demodulize(self.name)).to_sym,
          repository.name,
          options.fetch(:class_name, LazyMapper::Inflection.classify(name)),
          self.name,
          options
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.first
          end

          def #{name}=(child_resource)
            #{name}_association.replace(child_resource.nil? ? [] : [ child_resource ])
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
            relationship = self.class.relationships(#{repository.name.inspect})[:#{name}]
              association = Associations::OneToMany::Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        relationship
      end
    end
  end
end
