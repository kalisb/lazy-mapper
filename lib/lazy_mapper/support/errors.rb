# Some useful errors types
module LazyMapper
  class ValidationError < StandardError; end

  class ObjectNotFoundError < StandardError; end

  class MaterializationError < StandardError; end

  class RepositoryNotSetupError < StandardError; end

  class IncompleteResourceError < StandardError; end

  class PersistenceError < StandardError; end
end

class StandardError
  # Displays the specific error message and the backtrace associated with it.
  def display
    "#{message}\n\t#{backtrace.join("\n\t")}"
  end
end
