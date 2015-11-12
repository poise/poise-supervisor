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
    # (see SupervisorProgram::Resource)
    # @since 1.0.0
    module SupervisorProgram
      # A `supervisor_program` resource to create service users/groups.
      #
      # @provides supervisor_program
      # @action add
      # @action remove
      # @action start
      # @action stop
      # @action restart
      # @example
      #   supervisor_program 'myapp' do
      #     command '/usr/bin/myapp --port 80'
      #   end
      class Resource < SupervisorBase::Resource
        provides(:supervisor_program)

        parent_attribute(:group, type: :supervisor_group, optional: true, auto: false)
        attribute(:program_name, kind_of: String, name_attribute: true)
        attribute(:command, kind_of: String, required: true)
        attribute(:directory, kind_of: [String, NilClass, FalseClass])
        attribute(:environment, kind_of: Hash, default: lazy { {} })
        attribute(:user, kind_of: [String, NilClass, FalseClass])

        # DSL alias.
        alias_method :group, :parent_group

        def config_path
          ::File.join(parent.confd_path, "program_#{program_name}.conf")
        end

        private

        def program_ini_data
          {command: command}.tap do |ini_data|
            ini_data[:directory] = directory if directory
            # TODO: Handle quotes in value.
            ini_data[:environment] = environment.map {|key, value| "#{key}=\"#{value}\""}.join(',') if !environment.empty?
            ini_data[:user] = user if user
            ini_data.update(config)
          end
        end

        def default_config_options
          {ini: {"program:#{program_name}" => program_ini_data}}
        end
      end

      # Provider for `supervisor_program`.
      #
      # @see Resource
      # @provides supervisor_program
      class Provider < SupervisorBase::Provider
        provides(:supervisor_program)

        def action_start
          new_resource.parent.rpc.startProcess(new_resource.program_name)
        end

        def action_stop
          new_resource.parent.rpc.stopProcess(new_resource.program_name)
        end
      end
    end
  end
end
