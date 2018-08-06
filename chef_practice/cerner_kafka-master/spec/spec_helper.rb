require 'rspec/expectations'
require 'chefspec'
require 'chefspec/berkshelf'
require 'chef/node'
require_relative '../libraries/config_helper.rb'

RSpec.configure do |config|
  # Change to Ubuntu 16.04
  config.platform = 'Ubuntu'
  config.version = '16.04'
end

at_exit { ChefSpec::Coverage.report! }
