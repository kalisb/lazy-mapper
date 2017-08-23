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

  def count
    LazyMapper::Query::Operator.new(self, :count)
  end

  def min
    LazyMapper::Query::Operator.new(self, :min)
  end

  def max
    LazyMapper::Query::Operator.new(self, :max)
  end

  def avg
    LazyMapper::Query::Operator.new(self, :avg)
  end

  def sum
    LazyMapper::Query::Operator.new(self, :sum)
  end
end
