# Copyright 2014 SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

haproxy_loadbalancer "ceilometer-api" do
  address "0.0.0.0"
  port node[:ceilometer][:api][:port]
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "ceilometer", "ceilometer-server", "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-ceilometer_server_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-ceilometer_server_ha_resources"

primitives = []

["collector", "api"].each do |service|
  primitive_name = "ceilometer-#{service}"

  pacemaker_primitive primitive_name do
    agent node[:ceilometer][:ha][service.to_sym][:agent]
    op    node[:ceilometer][:ha][service.to_sym][:op]
    action :create
  end
  primitives << primitive_name
end

group_name = "g-ceilometer-server"

pacemaker_group group_name do
  members primitives
  action :create
end

pacemaker_clone "cl-#{group_name}" do
  rsc group_name
  action [ :create, :start]
end

crowbar_pacemaker_sync_mark "create-ceilometer_server_ha_resources"
