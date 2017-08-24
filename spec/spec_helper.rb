require 'pathname'
require 'simplecov'
SimpleCov.start

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/lazy_mapper'
require LazyMapper.root / 'spec' / 'lib' / 'mock_adapter'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end
# setup mock adapters
[ :default ].each do |repository_name|
  LazyMapper.establish_connection(repository_name, "mock://localhost/#{repository_name}")
end

def setup_adapter(name, default_uri)
  LazyMapper.establish_connection(name, ENV["#{name.to_s.upcase}_SPEC_URI"] || default_uri)
  Object.const_set('ADAPTER', ENV['ADAPTER'].to_sym) if name.to_s == ENV['ADAPTER']
  true
end

ENV['ADAPTER'] ||= 'sqlite3'

HAS_SQLITE3  = setup_adapter(:sqlite3,  'sqlite3:test.db')
HAS_POSTGRES = setup_adapter(:postgres, 'postgres://postgres:test@localhost/postgres')

LazyMapper::Logger.new(nil, :debug)
