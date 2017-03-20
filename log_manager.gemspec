Gem::Specification.new do |s|
  s.name        = 'log_manager'
  s.version     = '0.2.0'
  s.date        = '2017-03-01'
  s.summary     = 'Improved Logger'
  s.description = 'Manages the variables used to print logs'
  s.authors     = ['Pedro Rosanes']
  s.email       = 'prosanes@gmail.com'
  s.files       = ['lib/log_manager.rb']
  # s.homepage    =
  #  'http://rubygems.org/gems/log_ma'
  s.license     = 'MIT'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'byebug'
end
