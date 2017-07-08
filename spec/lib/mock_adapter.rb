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
end

module DataObjects
  module Mock

    def self.logger
    end

    def self.logger=(value)
    end

  end
end
