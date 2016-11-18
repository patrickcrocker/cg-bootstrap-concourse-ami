db_password = shell_out("tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1").stdout.strip
#concourse_binary_release = shell_out("curl https://api.github.com/repos/concourse/concourse/releases | grep browser_download_url | grep 'linux_amd64' | head -n 1 | cut -d'\"' -f4").stdout.strip

ci_default_username = "ci"
ci_default_password = "walt"

file '/etc/apt/sources.list.d/backports.list' do
  content 'deb http://archive.ubuntu.com/ubuntu trusty-backports main universe'
end

execute "apt-get-update" do
  command "apt-get update && apt-get update"
  action :run
end

package 'linux-generic-lts-wily'
package 'postgresql'

# make sure we get HAProxy 1.5 from backports for proper SSL support
apt_package "haproxy" do
  default_release "trusty-backports"
end

service 'concourse-web' do
  action [:stop]
  only_if { File.exist?("/etc/init/concourse-web.conf") }
end

execute 'drop-atc-database' do
  command "psql -c 'DROP DATABASE IF EXISTS atc'"
  user "postgres"
  action :run
end

execute 'drop-atc-user' do
  command "psql -c 'DROP ROLE IF EXISTS atc;'"
  user "postgres"
  action :run
end

execute 'create-postgres-user' do
  command "psql -c  \"CREATE USER atc WITH PASSWORD '#{db_password}';\""
  user "postgres"
  action :run
end

execute 'create-atc-database' do
  command "createdb -O atc atc"
  user "postgres"
  action :run
end

directory '/opt/concourse/bin' do
  recursive true
  action :create
end

directory '/opt/concourse/etc' do
  recursive true
  action :create
end

execute 'create-host-key' do
  command "ssh-keygen -t rsa -f /opt/concourse/etc/host_key -N ''"
  not_if do ::File.exists?('/opt/concourse/etc/host_key') end
  action :run
end

execute 'create-worker-key' do
  command "ssh-keygen -t rsa -f /opt/concourse/etc/worker_key -N ''"
  not_if do ::File.exists?('/opt/concourse/etc/worker_key') end
  action :run
end

execute 'create-session-key' do
  command "ssh-keygen -t rsa -f /opt/concourse/etc/session_signing_key -N ''"
  not_if do ::File.exists?('/opt/concourse/etc/session_signing_key') end
  action :run
end

cookbook_file '/opt/concourse/bin/extract_yaml_key' do
  source 'extract_yaml_key.py'
  mode 0755
end

template '/opt/concourse/bin/_userdata.sh' do
  mode 0755
  source 'userdata.erb'
  variables({
    :ci_default_username => ci_default_username,
    :ci_default_password => ci_default_password,
  })
end

cookbook_file '/opt/concourse/bin/concourse' do
  source 'concourse_linux_amd64'
  mode 0755
  action :create
end

template '/opt/concourse/bin/concourse-worker' do
  mode 0755
  source 'worker.erb'
end

template '/etc/init/concourse-worker.conf' do
  mode 0644
  source 'worker-init.erb'
end

template '/opt/concourse/bin/concourse-web' do
  mode 0755
  source 'web.erb'
  variables({
    :db_password => db_password
  })
end

template '/etc/init/concourse-web.conf' do
  mode 0644
  source 'web-init.erb'
end

template '/opt/concourse/bin/fly-bootstrap' do
  mode 0755
  source 'fly-bootstrap.erb'
end

template '/etc/init/concourse-bootstrap-fly.conf' do
  mode 0644
  source 'fly-init.erb'
end

service 'concourse-worker' do
  action [:enable, :start]
end

service 'concourse-web' do
  action [:enable, :start]
end

service 'concourse-bootstrap-fly' do
  action :enable
end

remote_file '/opt/concourse/bin/fly' do
  source 'http://localhost:8080/api/v1/cli?arch=amd64&platform=linux'
  headers("Authorization" => "Basic #{ Base64.encode64("#{ci_default_username}:#{ci_default_password}").gsub("\n", "") }" )
  mode 0755
  action :create
end

template '/etc/haproxy/haproxy.cfg' do
  mode 0644
  source 'haproxy.erb'
end

# generate a self-signed cert each time haproxy starts
template '/etc/default/haproxy' do
  source 'certgen.erb'
end

service 'haproxy' do
  action :enable
end
