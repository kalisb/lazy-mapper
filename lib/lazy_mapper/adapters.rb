dir = Pathname(__FILE__).dirname.expand_path / 'adapters'

require dir / 'abstract_adapter'
require dir / 'default_adapter'
require dir / 'sqlite3_adapter'
require dir / 'postgres_adapter'
