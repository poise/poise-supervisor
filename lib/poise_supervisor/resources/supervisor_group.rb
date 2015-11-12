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

require 'poise_supervisor/resources/supervisor_base'


module PoiseSupervisor
  module Resources
    # (see SupervisorGroup::Resource)
    # @since 1.0.0
    module SupervisorGroup
      # A `supervisor_group` resource to manage Supervisor program groups.
      #
      # @provides supervisor_group
      # @action add
      # @action remove
      # @action start
      # @action stop
      # @action restart
      # @example
      #   supervisor_group 'myapp' do
      #     programs %w{one two three}
      #   end
      class Resource < SupervisorBase::Resource
        poise_subresource_container
        provides(:supervisor_group)

        attribute(:group_name, kind_of: String, name_attribute: true)
        attribute(:programs, kind_of: Array, default: lazy { default_programs })

        def config_path
          ::File.join(parent.confd_path, "group_#{group_name}.conf")
        end

        private

        def default_config_options
          ini_data = {programs: programs.map(&:to_s).join(',')}
          ini_data.update(config)
          {ini: {"group:#{group_name}" => ini_data}}
        end

        def default_programs
          @subresources.select {|r| r.respond_to?(:program_name) }.map {|r| r.program_name }
        end
      end

      # Provider for `supervisor_group`.
      #
      # @see Resource
      # @provides supervisor_group
      class Provider < SupervisorBase::Provider
        provides(:supervisor_group)

        def action_start
          new_resource.parent.rpc.startProcessGroup(new_resource.group_name)
        end

        def action_stop
          new_resource.parent.rpc.stopProcessGroup(new_resource.group_name)
        end
      end
    end
  end
end
