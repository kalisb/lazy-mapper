module LazyMapper
  module Model
      attr_reader :query
      # Count results (given the conditions)
      def count(*args)
       query         = args.last.kind_of?(Hash) ? args.pop : {}
       property_name = args.first

       if property_name
         assert_kind_of 'property', property_by_name(property_name), Property
       end

       aggregate(query.merge(:fields => [ property_name ? property_name.count : :all.count ])).to_i
     end
  end
end
