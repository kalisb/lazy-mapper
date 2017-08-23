module LazyMapper
  module Adapters
    class MockAdapter < LazyMapper::Adapters::DefaultAdapter
      def create(_repository, instance)
        instance
      end

      def exists?(_storage_name)
        true
      end
    end
  end
  module Mock
    def self.logger
    end

    def self.logger=(_value)
    end

    class Connection
      def self.acquire(_uri)
        @connection = self
      end

      def self.close
      end

      def self.execute(_args)
      end
    end
  end
end
