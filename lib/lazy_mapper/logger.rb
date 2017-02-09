require "time" # httpdate
# ==== Public LazyMapper Logger API
#
# Logger taken from Merb :)
#
# To replace an existing logger with a new one:
#  LazyMapper::Logger.set_log(log{String, IO},level{Symbol, String})
#
# Available logging levels are
#   LazyMapper::Logger::{ Fatal, Error, Warn, Info, Debug }
#
# Logging via:
#   LazyMapper.logger.fatal(message<String>)
#   LazyMapper.logger.error(message<String>)
#   LazyMapper.logger.warn(message<String>)
#   LazyMapper.logger.info(message<String>)
#   LazyMapper.logger.debug(message<String>)
#
# Flush the buffer to
#   LazyMapper.logger.flush
#
# Remove the current log object
#   LazyMapper.logger.close
#
# ==== Private LazyMapper Logger API
#
# To initialize the logger you create a new object, proxies to set_log.
#   LazyMapper::Logger.new(log{String, IO},level{Symbol, String})
module LazyMapper

  class << self #:nodoc:
    attr_accessor :logger
  end

  class Logger

    attr_accessor :aio
    attr_accessor :level
    attr_accessor :delimiter
    attr_reader   :buffer
    attr_reader   :log

    # @note
    #   Ruby (standard) logger levels:
    #     fatal: an unhandleable error that results in a program crash
    #     error: a handleable error condition
    #     warn:  a warning
    #     info:  generic (useful) information about system operation
    #     debug: low-level information for developers
    #
    #   LazyMapper::Logger::LEVELS[:fatal, :error, :warn, :info, :debug]
    LEVELS =
    {
      :fatal => 7,
      :error => 6,
      :warn  => 4,
      :info  => 3,
      :debug => 0
    }

    private

    # The idea here is that instead of performing an 'if' conditional check on
    # each logging we do it once when the log object is setup
    def set_write_method
      @log.instance_eval do

        # Determine if asynchronous IO can be used
        def aio?
          @aio = !RUBY_PLATFORM.match(/java|mswin/) &&
          !(@log == STDOUT) &&
          @log.respond_to?(:write_nonblock)
        end

        # Define the write method based on if aio an be used
        undef write_method if defined? write_method
        if aio?
          alias :write_method :write_nonblock
        else
          alias :write_method :write
        end
      end
    end

    def initialize_log(log)
      close if @log # be sure that we don't leave open files laying around.
      log ||= "log/dm.log"
      if log.respond_to?(:write)
        @log = log
      else
        log = Pathname(log)
        log.dirname.mkpath
        @log = log.open('a')
        @log.sync = true
        @log.write("#{Time.now.httpdate} #{delimiter} info #{delimiter} Logfile created\n")
      end
      set_write_method
    end

    public

    # To initialize the logger you create a new object, proxies to set_log.
    #   LazyMapper::Logger.new(log{String, IO},level{Symbol, String})
    #
    # @param log<IO,String>     either an IO object or a name of a logfile.
    # @param log_level<String>  the message string to be logged
    # @param delimiter<String>  delimiter to use between message sections
    def initialize(*args)
      set_log(*args)
    end

    # To replace an existing logger with a new one:
    #  LazyMapper::Logger.set_log(log{String, IO},level{Symbol, String})
    #
    #
    # @param log<IO,String>     either an IO object or a name of a logfile.
    # @param log_level<Symbol>  a symbol representing the log level from
    #   {:fatal, :error, :warn, :info, :debug}
    # @param delimiter<String>  delimiter to use between message sections
    def set_log(log, log_level = nil, delimiter = " ~ ")
      if log_level && LEVELS[log_level.to_sym]
        @level = LEVELS[log_level.to_sym]
      else
        @level = LEVELS[:debug]
      end
      @buffer    = []
      @delimiter = delimiter

      initialize_log(log)

      LazyMapper.logger = self
    end

    # Flush the entire buffer to the log object.
    #   LazyMapper.logger.flush
    #
    def flush
      return unless @buffer.size > 0
      @log.write_method(@buffer.slice!(0..-1).to_s)
    end

    # Close and remove the current log object.
    #   LazyMapper.logger.close
    #
    def close
      flush
      @log.close if @log.respond_to?(:close)
      @log = nil
    end

    # Appends a string and log level to logger's buffer.

    # @note
    #   Note that the string is discarded if the string's log level less than the
    #   logger's log level.
    # @note
    #   Note that if the logger is aio capable then the logger will use
    #   non-blocking asynchronous writes.
    #
    # @param level<Fixnum>  the logging level as an integer
    # @param string<String> the message string to be logged
    def push(string)
      message = Time.now.httpdate
      message << delimiter
      message << string
      message << "\n" unless message[-1] == ?\n
      @buffer << message
      flush # Force a flush for now until we figure out where we want to use the buffering.
    end
    alias << push

    # Generate the following logging methods for LazyMapper.logger as described
    # in the API:
    #  :fatal, :error, :warn, :info, :debug
    LEVELS.each_pair do |name, number|
      class_eval <<-LEVELMETHODS, __FILE__, __LINE__
      # DOC
      def #{name}(message)
        self.<<(message) if #{name}?
      end

      # DOC
      def #{name}?
        #{number} >= level
      end
      LEVELMETHODS
    end

  end # class Logger
end # module LazyMapper
