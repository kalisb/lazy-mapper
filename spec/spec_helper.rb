require 'pathname'

require Pathname(__FILE__).dirname.expand_path.parent + 'lib/lazy_mapper'
require LazyMapper.root / 'spec' / 'lib' / 'mock_adapter'

# setup mock adapters
[ :default ].each do |repository_name|
  LazyMapper.setup(repository_name, "mock://localhost/#{repository_name}")
end

def setup_adapter(name, default_uri)
  begin
    LazyMapper.setup(name, ENV["#{name.to_s.upcase}_SPEC_URI"] || default_uri)
    Object.const_set('ADAPTER', ENV['ADAPTER'].to_sym) if name.to_s == ENV['ADAPTER']
    true
  rescue Exception => e
    if name.to_s == ENV['ADAPTER']
      Object.const_set('ADAPTER', nil)
      warn "Could not load #{name} adapter: #{e}"
    end
    false
  end
end

ENV['ADAPTER'] ||= 'sqlite3'

HAS_SQLITE3  = setup_adapter(:sqlite3,  'sqlite3::memory:')
HAS_MYSQL    = setup_adapter(:mysql,    'mysql://localhost/dm_core_test')

LazyMapper::Logger.new(nil, :debug)