require "time"
# ==== Public LazyMapper Logger API
module LazyMapper
  class << self
    attr_accessor :logger
  end

  class Logger
    attr_accessor :level
    attr_reader   :log

    ##
    #   LazyMapper::Logger::LEVELS[:fatal, :error, :warn, :info, :debug]
    LEVELS = {
      fatal: 7,
      error: 6,
      warn: 4,
      info: 3,
      debug: 0
    }

    private

    # The idea here is that instead of performing an 'if' conditional check on
    # each logging we do it once when the log object is setup
    def set_write_method
      @log.instance_eval do
        alias :write_method :write
      end
    end

    def initialize_log(log)
      close if @log
      log ||= "log/lazy_mapper.log"
      if log.respond_to?(:write)
        @log = log
      else
        log = Pathname(log)
        log.dirname.mkpath
        @log = log.open('a')
        @log.sync = true
      end
      set_write_method
    end

    public

    # To initialize the logger you create a new object, proxies to set_log.
    # @param log<IO,String>     either an IO object or a name of a logfile.
    # @param log_level<String>  the message string to be logged
    def initialize(*args)
      set_log(*args)
    end

    # To replace an existing logger with a new one:
    def set_log(log, log_level = nil)
      @level = if log_level && LEVELS[log_level.to_sym]
                 LEVELS[log_level.to_sym]
               else
                 LEVELS[:debug]
               end
      initialize_log(log)

      LazyMapper.logger = self
    end

    # Close and remove the current log object.
    def close
      flush
      @log.close if @log.respond_to?(:close)
      @log = nil
    end

    # Appends a string and log level to logger's buffer.
    def push(string)
      message = Time.now.httpdate
      message << ' [ '
      message << LEVELS.key(level).to_s
      message << ' ] '
      message << string.to_s
      message << "\n" unless message[-1] == ?\n
      @log.write_method(message)
    end
    alias_method '<<', 'push'

    # Generate the following logging methods for LazyMapper.logger as described
    # in the API:
    #  :fatal, :error, :warn, :info, :debug
    LEVELS.each_pair do |name, _|
      define_method(name.to_s) do |message|
        self.<<(message) if level <= LEVELS[name]
      end
    end
  end
end
