class Symbol
  def gt
    LazyMapper::Query::Operator.new(self, :gt)
  end

  def gte
    LazyMapper::Query::Operator.new(self, :gte)
  end

  def lt
    LazyMapper::Query::Operator.new(self, :lt)
  end

  def lte
    LazyMapper::Query::Operator.new(self, :lte)
  end

  def not
    LazyMapper::Query::Operator.new(self, :not)
  end

  def eql
    LazyMapper::Query::Operator.new(self, :eql)
  end

  def like
    LazyMapper::Query::Operator.new(self, :like)
  end

  def in
    LazyMapper::Query::Operator.new(self, :in)
  end

  def asc
    LazyMapper::Query::Operator.new(self, :asc)
  end

  def desc
    LazyMapper::Query::Operator.new(self, :desc)
  end

  def to_proc
    lambda { |value| value.send(self) }
  end
end # class Symbol
