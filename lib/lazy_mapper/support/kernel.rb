module Kernel
  # Delegates to LazyMapper::repository.
  # Will not overwrite if a method of the same name is pre-defined.
  def repository(*args, &block)
    LazyMapper.repository(*args, &block)
  end
end # module Kernel
