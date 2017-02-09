dir = Pathname(__FILE__).dirname.expand_path / 'associations'

require dir / 'relationship'
require dir / 'relationship_chain'
require dir / 'many_to_many'
require dir / 'many_to_one'
require dir / 'one_to_many'
require dir / 'one_to_one'

module LazyMapper
  module Associations

    class ImmutableAssociationError < RuntimeError
    end

    include ManyToOne
    include OneToMany
    include ManyToMany
    include OneToOne

    def relationships(repository_name = default_repository_name)
      @relationships ||= Hash.new { |h,k| h[k] = k == Repository.default_name ? {} : h[Repository.default_name].dup }
      @relationships[repository_name]
    end

    def n
      1.0/0
    end

    #
    # A shorthand, clear syntax for defining one-to-one, one-to-many and
    # many-to-many resource relationships.
    #
    # @example [Usage]
    #   * has 1, :friend                          # one_to_one, :friend
    #   * has n, :friends                         # one_to_many :friends
    #   * has 1..3, :friends
    #                         # one_to_many :friends, :min => 1, :max => 3
    #   * has 3, :friends
    #                         # one_to_many :friends, :min => 3, :max => 3
    #   * has 1, :friend, :class_name => 'User'
    #                         # one_to_one :friend, :class_name => 'User'
    #   * has 3, :friends, :through => :friendships
    #                         # one_to_many :friends, :through => :friendships
    #   * has n, :friendships => :friends
    #                         # identical to above example
    #
    # @param cardinality <Fixnum, Bignum, Infinity, Range>
    #   cardinality that defines the association type and constraints
    # @param name <Symbol>  the name that the association will be referenced by
    # @param opts <Hash>    an options hash
    #
    # @option :through<Symbol>  A association that this join should go through to form
    #       a many-to-many association
    # @option :class_name<String> The name of the class to associate with, if omitted
    #       then the association name is assumed to match the class name
    # @option :remote_name<Symbol> In the case of a :through option being present, the
    #       name of the relationship on the other end of the :through-relationship
    #       to be linked to this relationship.
    #
    # @return <LazyMapper::Association::Relationship> the relationship that was
    #   created to reflect either a one-to-one, one-to-many or many-to-many
    #   relationship
    # @raise <ArgumentError> if the cardinality was not understood. Should be a
    #   Fixnum, Bignum, Infinity(n) or Range
    #
    # @api public
    def has(cardinality, name, options = {})
      options = options.merge(extract_min_max(cardinality))
      options = options.merge(extract_throughness(name))

      # do not remove this. There is alot of confusion on people's
      # part about what the first argument to has() is.  For the record it
      # is the cardinality, or rather the min and max number of results
      # the association will return.  It is not, as has been assumed,
      # the number of results on the left and right hand side of the
      # reltionship.
      raise ArgumentError, 'Cardinality may not be n..n.  The cardinality specifies the min/max number of results from the association' if options[:min] == n && options[:max] == n

      relationship = if options[:max] == 1
        one_to_one(options.delete(:name), options)
      else
        one_to_many(options.delete(:name), options)
      end

      # Please leave this in - I will release contextual serialization soon
      # which requires this -- guyvdb
      # TODO convert this to a hook in the plugin once hooks work on class
      # methods
      self.init_has_relationship_for_serialization(relationship) if self.respond_to?(:init_has_relationship_for_serialization)

      relationship
    end

    #
    # A shorthand, clear syntax for defining many-to-one resource relationships.
    #
    # @example [Usage]
    #   * belongs_to :user                          # many_to_one, :friend
    #   * belongs_to :friend, :class_name => 'User'  # many_to_one :friends
    #
    # @param name<Symbol> The name that the association will be referenced by
    # @param opts<Hash>   An options hash (see below)
    # @see #has
    #
    # @return <LazyMapper::Association::ManyToOne> The association created
    #   should not be accessed directly
    #
    # @api public
    def belongs_to(name, options={})
      relationship = many_to_one(name, options)
      # Please leave this in - I will release contextual serialization soon
      # which requires this -- guyvdb
      # TODO convert this to a hook in the plugin once hooks work on class
      # methods
      self.init_belongs_relationship_for_serialization(relationship) if self.respond_to?(:init_belongs_relationship_for_serialization)
    end


  private

    def extract_throughness(name)
      case name
      when Hash
        {:name => name.values.first, :through => name.keys.first}
      when Symbol
        {:name => name}
      else
        raise ArgumentError, "Name of association must be Hash or Symbol, not #{name.inspect}"
      end
    end

    # A support method form converting Fixnum, Range or Infinity values into a
    # {:min=>x, :max=>y} hash.
    #
    # @api private
    def extract_min_max(constraints)
      case constraints
        when Range
          raise ArgumentError, "Constraint min (#{constraints.first}) cannot be larger than the max (#{constraints.last})" if constraints.first > constraints.last
          { :min => constraints.first, :max => constraints.last }
        when Fixnum, Bignum
          { :min => constraints, :max => constraints }
        when n
          {}
        else
          raise ArgumentError, "Constraint #{constraints.inspect} (#{constraints.class}) not handled must be one of Range, Fixnum, Bignum, Infinity(n)"
      end
    end
  end # module Associations

  module Resource
    module ClassMethods
      include LazyMapper::Associations
    end # module ClassMethods
  end # module Resource
end # module LazyMapper
