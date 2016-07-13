require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.pattern = "spec/*_spec.rb"
end

task :default => :spec
