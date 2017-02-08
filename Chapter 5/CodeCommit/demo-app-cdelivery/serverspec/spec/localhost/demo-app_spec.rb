require 'spec_helper'

versionFile = open('/tmp/APP_VERSION')
appVersion = versionFile.read.chomp

describe package("demo-app-#{appVersion}") do
  it { should be_installed }
end

describe service('php-fpm') do
  it { should be_enabled }
  it { should be_running }
end

describe service('nginx') do
  it { should be_enabled }
  it { should be_running }
end

describe user('veselin') do
  it { should exist }
  it { should have_authorized_key 'ssh-rsa AAAAB3NzaC1yc...' }
end
