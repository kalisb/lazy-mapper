module LazyMapper
  class Relation

    attr_reader :options, :repository, :klass

    VALUE_METHODS = [:limit, :offset, :order]


    def initialize(repository, klass, options = {})
      @repository = repository
      @klass = klass
      @options = Hash.new
      @options = @options.merge(options)
    end

    def method_missing(method, *args, &block)
      if @klass.respond_to?(method)
        if (VALUE_METHODS.include? method)
          args = args.at(0) if Array === args
          options_map = {method.to_sym => args}
          @options = @options.merge(options_map)
          self
        else
          @options = @options.merge(args)
          self
        end
      else
        super
      end
    end

    def to_a
      @repository.all(@klass, @options)
    end
  end
end
