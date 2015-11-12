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

require 'chef/resource'
require 'chef/provider'
require 'poise'


module PoiseSupervisor
  module Resources
    # (see SupervisorBase::Resource)
    # @api private
    # @since 1.0.0
    module SupervisorBase
      # A resource base class for Supervisor types.
      #
      # @action add
      # @action remove
      # @action start
      # @action stop
      # @action restart
      class Resource < Chef::Resource
        include Poise(parent: :supervisord)
        actions(:add, :remove, :start, :stop, :restart)

        attribute(:config, option_collector: true)
        attribute(:config, template: true, default_source: 'ini.conf.erb', default_options: lazy { default_config_options })

        def config_path
          raise NotImplementedError
        end

        private

        def default_config_options
          raise NotImplementedError
        end
      end

      # Provider base class for Supervisor types.
      #
      # @see Resource
      class Provider < Chef::Provider
        include Poise

        # `add` action for Supervisor types. Create the config file and
        # trigger an reread on the daemon.
        #
        # @return [void]
        def action_add
          notifying_block do
            create_config
          end
        end

        # `remove` action for Supervisor types. Remove the config and
        # trigger a reread on the daemon.
        #
        # @return [void]
        def action_remove
          notifying_block do
            delete_config
          end
        end

        def action_start
          raise NotImplementedError
        end

        def action_stop
          raise NotImplementedError
        end

        def action_restart
          action_stop
          action_start
        end

        private

        def create_config
          file new_resource.config_path do
            content new_resource.config_content
            group new_resource.parent.group if new_resource.parent.group
            mode '600'
            owner new_resource.parent.owner if new_resource.parent.owner
            notifies :reread, new_resource.parent, :immediately
          end
        end

        def delete_config
          create_config.tap do |r|
            r.action(:delete)
          end
        end

      end
    end
  end
end
