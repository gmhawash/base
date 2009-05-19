task :reset_database => ['db:migrate:reset', 'db:test:clone_structure', 'db:bootstrap'] do 
  #triggers are disabled during fixture load; this updates the full_text_vector column
  ActiveRecord::Base.connection.execute "UPDATE item_versions SET body = body || ''"
  #ActiveRecord::Base.connection.execute "UPDATE issue_areas SET body = body || ''"
end
