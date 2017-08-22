# This file begins the loading sequence.

# Require the basics...
require 'addressable/uri'

dir = Pathname(__FILE__).dirname.expand_path / 'lazy_mapper'

require dir / 'associations'
require dir / 'model'
require dir / 'tables'
require dir / 'hook'
require dir / 'identity_map'
require dir / 'logger'
require dir / 'type_map'
require dir / 'naming_conventions'
require dir / 'property_set'
require dir / 'query'
require dir / 'repository'
require dir / 'model'
require dir / 'relation'
require dir / 'scope'
require dir / 'support'
require dir / 'property'
require dir / 'adapters'
require dir / 'collection'
require dir / 'version'

##
# LazyMapper uses URIs to connect to your data-store.
# URI connections takes the form of:
#   LazyMapper.setup(:default, 'protocol://username:password@localhost:port/path/to/repo')
#
module LazyMapper
  def self.root
    @root ||= Pathname(__FILE__).dirname.parent.expand_path
  end

  ##
  # Setups up a connection to a data-store
  def self.setup(name, uri_or_options)
    raise ArgumentError, "+name+ must be a Symbol, but was #{name.class}", caller unless Symbol === name

    case uri_or_options
    when Hash
      adapter_name = uri_or_options[:adapter]
    when String, Addressable::URI
      uri_or_options = Addressable::URI.parse(uri_or_options) if String === uri_or_options
      adapter_name = uri_or_options.scheme
    else
      raise ArgumentError, "+uri_or_options+ must be a Hash, Addressable::URI or String, but was #{uri_or_options.class}", caller
    end

    class_name = LazyMapper::Inflection.classify(adapter_name) + 'Adapter'

    Repository.adapters[name] = Adapters.const_get(class_name).new(name, uri_or_options)
  end

  ##
  #   Pushes the named repository onto the context-stack,
  #   yields a new session, and pops the context-stack.
  #
  def self.repository(*args)
    raise ArgumentError, "Can only pass in one optional argument, but passed in #{args.size} arguments", caller unless args.size <= 1
    raise ArgumentError, "First optional argument must be a Symbol, but was #{args.first.inspect}", caller      unless args.empty? || Symbol === args.first

    name = args.first

    current_repository = if name
                           Repository.context.detect { |r| r.name == name } || Repository.new(name)
                         else
                           Repository.context.last || Repository.new(Repository.default_name)
                         end

    return current_repository unless block_given?

    Repository.context << current_repository

    begin
      return yield(current_repository)
    ensure
      Repository.context.pop
    end
  end

  # A logger should always be present.
  Logger.new(nil, :fatal)

  def self.prepare(*args)
    yield repository(*args)
  end
end
