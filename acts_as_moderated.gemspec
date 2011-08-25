Gem::Specification.new do |s|
  s.name     = "acts_as_moderated"
  s.version  = "1.0.0"
  s.date     = "2010-6-12"
  s.summary  = "Moderation Queue for ActiveRecord Models"
  s.email    = "mark@humansized.com"
  s.homepage = "http://github.com/heavysixer/acts_as_moderated/tree/master"
  s.description = "ActsAsModerated is a plugin that allows some or all of the columns of a model to be audited by a moderator at some later point."
  s.authors  = ["Mark Daggett"]

  s.has_rdoc = false
  s.rdoc_options = ["--main", "README.textile"]
  s.extra_rdoc_files = ["README.textile"]

  # run git ls-files to get an updated list
  s.files = %w[
    MIT-LICENSE
    README.textile
    Rakefile
    init.rb
    install.rb
    lib/acts_as_moderated.rb
    lib/moderation_record.rb
    tasks/acts_as_moderated_tasks.rake
    test/acts_as_moderated_test.rb
    test/test_helper.rb
    uninstall.rb
  ]
  s.test_files = %w[
    spec/acts_as_moderated_spec.rb
    spec/database.rb
    spec/spec_helper.rb
  ]
end