module LazyMapper
  class Command
    attr_reader :text, :timeout, :connection

    # initialize creates a new Command object
    def initialize(connection, text)
      @connection, @text = connection, text
    end
  end
end
