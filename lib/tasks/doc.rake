task :diagram_database do
  `postgresql_autodoc -t dot -u csg -d csg_development`
  `dot -Tpdf csg_development.dot > #{RAILS_ROOT}/doc/csg_development.pdf`
  File.unlink('csg_development.dot')
  puts "Created #{RAILS_ROOT}/doc/csg_development.pdf"
end
