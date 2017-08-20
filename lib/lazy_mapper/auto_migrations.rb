module LazyMapper
   module AutoMigrations
     def auto_migrate!(repository_name = nil)
       repository_name ||= default_repository_name
       repository(repository_name) do |r|
         (relationships(r.name)||{}).each_value { |relationship| relationship.child_key }
         r.adapter.destroy_model_storage(r, self)
         r.adapter.create_model_storage(r, self)
       end
     end

     def auto_upgrade!(repository_name = nil)
       repository_name ||= default_repository_name
       repository(repository_name) do |r|
         (relationships(r.name)||{}).each_value { |relationship| relationship.child_key }
         r.adapter.upgrade_model_storage(r, self)
       end
     end
   end # module AutoMigrations



   module ClassMethods
     include AutoMigrations
  end # module ClassMethods
end # module LazyMapper
