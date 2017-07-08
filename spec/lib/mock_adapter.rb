module LazyMapper
  module Adapters
    class MockAdapter < LazyMapper::Adapters::DefaultAdapter

      def create(repository, instance)
        instance
      end

      def exists?(storage_name)
        true
      end

    end
  end
  module Mock

      def self.logger
      end

      def self.logger=(value)
      end

      class Connection
        def self.acquire(uri)
          @connection = self
        end

        def self.close
        end

        def self.execute(args)
        end
      end
  end
end
