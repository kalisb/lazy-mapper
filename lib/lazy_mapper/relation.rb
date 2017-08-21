module LazyMapper
  module Relation
    MULTI_VALUE_METHODS  = [:all, :order, :first, :where, :last]
    SINGLE_VALUE_METHODS = [:limit, :offset]
  end
  class Reletaion
    extend LazyMapper::Associations
  end # module ClassMethods
end
