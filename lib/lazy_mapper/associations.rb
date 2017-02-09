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
    #
    def has(cardinality, name, options = {})
      options = options.merge(extract_min_max(cardinality))
      options = options.merge(extract_throughness(name))

      raise ArgumentError, 'Cardinality may not be n..n.  The cardinality specifies the min/max number of results from the association' if options[:min] == n && options[:max] == n

      relationship = if options[:max] == 1
        one_to_one(options.delete(:name), options)
      else
        one_to_many(options.delete(:name), options)
      end
      relationship
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
