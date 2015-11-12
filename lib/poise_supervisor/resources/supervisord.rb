#
# Copyright 2015, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider'
require 'chef/resource'
require 'poise'
require 'poise_python/python_command_mixin'
require 'poise_service/service_mixin'

require 'poise_supervisor/utils'


module PoiseSupervisor
  module Resources
    # (see Supervisord::Resource)
    # @since 1.0.0
    module Supervisord
      # A `supervisord` resource to install and configure Supervisord.
      #
      # @provides supervisord
      # @action enable
      # @action disable
      # @action start
      # @action stop
      # @action restart
      # @action reload
      # @example
      #   supervisord '/opt/myapp/requirements.txt'
      class Resource < Chef::Resource
        include Poise(container: true)
        include PoisePython::PythonCommandMixin
        provides(:supervisord)
        include PoiseService::ServiceMixin
        actions(:reread)

        attribute(:ctl_listen, kind_of: [String, Integer, NilClass, FalseClass], default: lazy { default_ctl_listen })
        attribute(:ctl_password, kind_of: [String, NilClass, FalseClass])
        attribute(:ctl_username, kind_of: [String, NilClass, FalseClass])
        attribute(:config, option_collector: true)
        attribute(:config, template: true, default_source: 'supervisord.conf.erb', default_options: lazy { default_config_options })
        attribute(:group, kind_of: [String, NilClass], default: nil)
        attribute(:owner, kind_of: [String, NilClass], default: nil)
        attribute(:path, kind_of: String, default: '/etc')
        attribute(:version, kind_of: [String, NilClass, FalseClass], default: nil)

        def confd_path
          ::File.join(path, 'supervisor.d')
        end

        # Return an XML-RPC proxy object for this Supervisord server.
        #
        # @return [XMLRPC::Client::Proxy]
        def rpc
          @rpc ||= begin
            params = {path: '/RPC2'}
            if ctl_is_inet?
              params.update(host: @ctl_bind_host, port: @ctl_bind_port)
            else
              params[:host] = ctl_listen
            end
            params[:user] = ctl_username if ctl_username
            params[:password] = ctl_password if ctl_password
            client = PoiseSupervisor::Utils::RpcClient.new_from_hash(params)
            client.proxy('supervisor')
          end
        end

        private

        def ctl_is_inet?
          @ctl_is_inet ||= ctl_listen.to_s.match(/^(|\*|[0-9.]+:)?(\d+)$/).tap do |match|
            # Either numeric or IP/port, means inet.
            if match
              @ctl_bind_host = if !match[1] || match[1].empty? || match[1] == '*'
                # For the purposes for supervisorctl, localhost is fine.
                '127.0.0'
              else
                match[1]
              end
              @ctl_bind_port = match[2]
            end
          end
        end

        # Default listen path, we default to unix sockets for security.
        #
        # @return [String]
        def default_ctl_listen
          socket_name = if service_name == 'supervisor'
            'supervisor.sock'
          else
            "supervisor-#{service_name}.sock"
          end
          # File.join is largely symbolic, this can't run on Windows anyway.
          ::File.join('', 'tmp', socket_name)
        end

        # Default template options for the config file.
        #
        # @return [Hash]
        def default_config_options
          ini_data = {
            supervisord: config,
            supervisorctl: {},
            'rpcinterface:supervisor' => {'supervisor.rpcinterface_factory' => 'supervisor.rpcinterface:make_main_rpcinterface'},
            'include' => {files: ::File.join(confd_path, '*.conf') },
          }
          # Are we using unix or inet?
          if ctl_is_inet?
            # Either numeric or IP/port, means inet.
            ini_data[:inet_http_server] = {port: ctl_listen}
            ini_data[:inet_http_server][:password] = ctl_password if ctl_password
            ini_data[:inet_http_server][:username] = ctl_username if ctl_username
            ini_data[:supervisorctl][:serverurl] = "http://#{@ctl_bind_host}:#{@ctl_bind_port}"
          else
            # Otherwise, Unix sockets.
            ini_data[:unix_http_server] = {file: ctl_listen}
            ini_data[:unix_http_server][:password] = ctl_password if ctl_password
            ini_data[:unix_http_server][:username] = ctl_username if ctl_username
            # Maybe deal with chmod somehow? Defaults are safe I think.
            if owner
              chown = owner.dup
              if group
                chown << ':'
                chown << group
              end
              ini_data[:unix_http_server][:chown] = chown
            end
            ini_data[:supervisorctl][:serverurl] = "unix://#{ctl_listen}"
          end
          ini_data[:supervisorctl][:password] = ctl_password if ctl_password
          ini_data[:supervisorctl][:username] = ctl_username if ctl_username
          {ini: ini_data}
        end
      end

      # The default provider for `supervisord`.
      #
      # @see Resource
      # @provides supervisord
      class Provider < Chef::Provider
        include Poise
        provides(:supervisord)
        include PoiseService::ServiceMixin

        # The `enable` action for the `supervisord` resource.
        #
        # @return [void]
        def action_enable
          notifying_block do
            install_package
            create_confd_directory
            write_config
          end
          super
        end

        # The `disable` action for the `supervisord` resource.
        #
        # @return [void]
        def action_disable
          super
        end

        # The `reread` action for the `supervisord` resource.
        #
        # @return [void]
        def action_reread
          added, _changed, removed = new_resource.rpc.reloadConfig()[0]
          added.each {|name| new_resource.rpc.addProcessGroup(name) }
          removed.each {|name| new_resource.rpc.removeProcessGroup(name) }
        end

        private

        def install_package
          python_package 'supervisor' do
            action :upgrade unless new_resource.version
            group new_resource.group if new_resource.group
            python_from_parent new_resource
            user new_resource.owner if new_resource.owner
            version new_resource.version if new_resource.version
          end
        end

        def create_confd_directory
          directory new_resource.confd_path do
            group new_resource.group if new_resource.group
            mode '700'
            owner new_resource.owner if new_resource.owner
          end
        end

        def write_config
          file ::File.join(new_resource.path, 'supervisord.conf') do
            content new_resource.config_content
            group new_resource.group if new_resource.group
            mode '600'
            owner new_resource.owner if new_resource.owner
          end
        end

        def service_options(r)
          r.command("#{new_resource.python} -m supervisor.supervisord --nodaemon --configuration #{::File.join(new_resource.path, 'supervisord.conf')}")
          r.environment.update(new_resource.parent_python.python_environment) if new_resource.parent_python
        end

      end
    end
  end
end
