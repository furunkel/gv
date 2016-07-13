require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.pattern = "spec/*_spec.rb"
end


YARD::Rake::YardocTask.new


task :default => :test
