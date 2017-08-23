# The original of this file was copied for the ActiveSupport project which is
# part of the Ruby On Rails web-framework (http://rubyonrails.org)
#
# Methods have been modified or removed. English inflection is now provided via
# the english gem (http://english.rubyforge.org)
#
# sudo gem install english
#
gem 'english', '>=0.2.0'
require 'english/inflect'

English::Inflect.word 'postgres'

module LazyMapper
  module Inflection
    class << self
      # Take an underscored name and make it into a camelized name
      def classify(name)
        camelize(singularize(name.to_s.sub(/.*\./, '')))
      end

      # By default, camelize converts strings to UpperCamelCase.
      def camelize(lower_case_and_underscored_word)
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
      end

      # The reverse of +camelize+. Makes an underscored form from the expression in the string.
      #
      # Changes '::' to '/' to convert namespaces to paths.
      def underscore(camel_cased_word)
        camel_cased_word.to_s
          .gsub(/::/, '/')
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .tr("-", "_")
          .downcase
      end

      # Capitalizes the first word and turns underscores into spaces and strips _id.
      # Like titleize, this is meant for creating pretty output.
      def humanize(lower_case_and_underscored_word)
        lower_case_and_underscored_word.to_s.gsub(/_id$/, "").gsub(/_/, " ").capitalize
      end

      # Removes the module part from the expression in the string
      #
      def demodulize(class_name_in_module)
        class_name_in_module.to_s.gsub(/^.*::/, '')
      end

      # Create the name of a table like Rails does for models to table names. This method
      # uses the pluralize method on the last word in the string.
      #
      def tableize(class_name)
        pluralize(underscore(class_name))
      end

      # Creates a foreign key name from a class name.
      def foreign_key(class_name, key = "id")
        underscore(demodulize(class_name.to_s)) << "_" << key.to_s
      end

      # Constantize tries to find a declared constant with the name specified
      # in the string. It raises a NameError when the name is not in CamelCase
      # or is not initialized.
      def constantize(camel_cased_word)
        unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
          raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
        end

        Object.module_eval("::#{$1}", __FILE__, __LINE__)
      end

      # The reverse of pluralize, returns the singular form of a word in a string.
      # Wraps the English gem
      def singularize(word)
        English::Inflect.singular(word)
      end

      # Returns the plural form of the word in the string.
      def pluralize(word)
        English::Inflect.plural(word)
      end
    end
  end
end
