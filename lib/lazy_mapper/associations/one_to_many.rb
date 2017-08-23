require 'forwardable'

module LazyMapper
  module Associations
    module OneToMany
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :remote_name ]

      private

      def one_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol (or Hash for +through+ support), but was #{name.class}", caller unless Symbol === name || Hash === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash === options

        relationship =
          relationships(repository.name)[name] = if options.include?(:through)
                                                   RelationshipChain.new(
                                                     child_model_name: options.fetch(:class_name, LazyMapper::Inflection.classify(name)),
                                                     parent_model_name: self.name,
                                                     repository_name: repository.name,
                                                     near_relationship_name: options[:through],
                                                     remote_relationship_name: options.fetch(:remote_name, name),
                                                     parent_key: options[:parent_key],
                                                     child_key: options[:child_key]
                                                   )
                                                 else
                                                   relationships(repository.name)[name] =
                                                     Relationship.new(
                                                       LazyMapper::Inflection.underscore(self.name.split('::').last).to_sym,
                                                       repository.name,
                                                       options.fetch(:class_name, LazyMapper::Inflection.classify(name)),
                                                       self.name,
                                                       options
                                                     )
                                                 end

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}(options={})
            options.empty? ? #{name}_association : #{name}_association.all(options)
          end

          def #{name}=(children)
            #{name}_association.replace(children)
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              relationship = self.class.relationships(#{repository.name.inspect})[#{name.inspect}]
              raise ArgumentError.new("Relationship #{name.inspect} does not exist") unless relationship
              association = Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        relationship
      end

      class Proxy < BasicObject
        def replace(resources)
          each { |resource| remove_resource(resource) }
          append_resource(resources)
          children.replace(resources)
          self
        end

        def push(*resources)
          append_resource(resources)
          children.push(*resources)
          self
        end

        def unshift(*resources)
          append_resource(resources)
          children.unshift(*resources)
          self
        end

        def <<(resource)
          #
          # The order here is of the essence.
          #
          # self.append_resource used to be called before children.<<, which created weird errors
          # where the resource was appended in the db before it was appended onto the @children
          # structure, that was just read from the database, and therefore suddenly had two
          # elements instead of one after the first addition.
          #
          children << resource
          append_resource([ resource ])
          self
        end

        def pop
          remove_resource(children.pop)
        end

        def shift
          remove_resource(children.shift)
        end

        def delete(resource, &block)
          remove_resource(children.delete(resource, &block))
        end

        def delete_at(index)
          remove_resource(children.delete_at(index))
        end

        def clear
          each { |resource| remove_resource(resource) }
          children.clear
          self
        end

        def save
          save_resources(@dirty_children)
          @dirty_children = []
          self
        end

        def all(options = {})
          options.empty? ? children : @relationship.get_children(@parent_resource, options, :all)
        end

        def first(options = {})
          options.empty? ? children.first : @relationship.get_children(@parent_resource, options, :first)
        end

        def reload!
          @dirty_children = []
          @children = nil
          self
        end

        private

        def initialize(relationship, parent_resource)
          @relationship    = relationship
          @parent_resource = parent_resource
          @dirty_children  = []
        end

        def children
          @children ||= @relationship.get_children(@parent_resource)
        end

        def ensure_mutable
          raise ImmutableAssociationError, "You can not modify this assocation" if RelationshipChain === @relationship
        end

        def add_default_association_values(resources)
          resources.each do |resource|
            conditions = @relationship.query.reject { |key, _| key == :order }
            conditions.each do |key, value|
              resource.send("#{key}=", value) if key.class != LazyMapper::Query::Operator && resource.send(key.to_s) == nil
            end
          end
          resources
        end

        def remove_resource(resource)
          ensure_mutable
          begin
            repository(@relationship.repository_name) do
              @relationship.attach_parent(resource, nil)
              resource.save
            end
          rescue
            children << resource
            raise
          end
          resource
        end

        def append_resource(resources = [])
          ensure_mutable
          add_default_association_values(resources)
          if @parent_resource.new_record?
            @dirty_children.push(*resources)
          else
            save_resources(resources)
          end
        end

        def save_resources(resources = [])
          ensure_mutable
            resources.each do |resource|
              @relationship.attach_parent(resource, @parent_resource)
              resource.save
            end
        end

        def method_missing(method, *args, &block)
          children.__send__(method, *args, &block)
        end
      end
    end
  end
end
