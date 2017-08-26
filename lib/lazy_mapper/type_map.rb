module LazyMapper
  class TypeMap
    attr_accessor :parent, :chains

    def initialize(parent = nil, &blk)
      @parent = parent
      @chains = {}

      yield self unless blk.nil?
    end

    def map(type)
      @chains[type] ||= TypeChain.new
    end

    def lookup(type)
      lookup_from_map(type)
    end

    def lookup_from_map(type)
      lookup_from_parent(type).merge(map(type).translate)
    end

    def lookup_from_parent(type)
      if !@parent.nil? && @parent.type_mapped?(type)
        @parent[type]
      else
        {}
      end
    end

    alias_method '[]', 'lookup'

    def type_mapped?(type)
      @chains.key?(type) || (@parent.nil? ? false : @parent.type_mapped?(type))
    end

    class TypeChain
      attr_accessor :primitive, :attributes

      def initialize
        @attributes = {}
      end

      def to(primitive)
        @primitive = primitive
        self
      end

      def with(attributes)
        raise "method 'with' expects a hash" unless Hash === attributes
        @attributes.merge!(attributes)
        self
      end

      def translate
        @attributes.merge((@primitive.nil? ? {} : {primitive: @primitive}))
      end
    end
  end
end
