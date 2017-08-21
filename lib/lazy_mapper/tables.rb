module LazyMapper
   module Table
     def create_table(repository_name = nil)
       repository_name ||= default_repository_name
       repository(repository_name) do |r|
         (relationships(r.name)||{}).each_value { |relationship|  relationship.child_key }
         r.adapter.destroy_model_storage(r, self)
         r.adapter.create_model_storage(r, self)
       end
     end

     def update_table(repository_name = nil)
       repository_name ||= default_repository_name
       repository(repository_name) do |r|
         (relationships(r.name)||{}).each_value { |relationship| relationship.child_key }
         r.adapter.upgrade_model_storage(r, self)
       end
     end
   end # module table

   module ClassMethods
     include Table
  end # module ClassMethods
end # module LazyMapper
