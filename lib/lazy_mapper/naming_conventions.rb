module LazyMapper
  # Use these modules to establish naming conventions.
  module NamingConventions
    module UnderscoredAndPluralized
      def self.call(value)
        LazyMapper::Inflection.pluralize(LazyMapper::Inflection.underscore(value)).gsub('/', '_')
      end
    end

    module UnderscoredAndPluralizedWithoutModule
      def self.call(value)
        LazyMapper::Inflection.pluralize(LazyMapper::Inflection.underscore(LazyMapper::Inflection.demodulize(value)))
      end
    end

    module Underscored
      def self.call(value)
        LazyMapper::Inflection.underscore(value)
      end
    end
  end
end
