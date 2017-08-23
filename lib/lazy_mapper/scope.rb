module LazyMapper
  module Scope
    protected

    def with_scope(query, &block)
      with_exclusive_scope(current_scope ? current_scope.merge(query) : query, &block)
    end

    def with_exclusive_scope(query, &block)
      query = LazyMapper::Query.new(repository, self, query) if Hash === query

      scope_stack << query

      begin
        yield unless block.nil
      ensure
        scope_stack.pop
      end
    end

    private

    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= Hash.new { |h, k| h[k] = [] }
      scope_stack_for[self]
    end

    def current_scope
      scope_stack.last
    end
  end

  module ClassMethods
    include Scope
  end
end
