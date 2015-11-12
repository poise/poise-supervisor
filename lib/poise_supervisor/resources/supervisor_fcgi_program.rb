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

require 'poise_supervisor/resources/supervisor_program'


module PoiseSupervisor
  module Resources
    # (see SupervisorFcgiProgram::Resource)
    # @since 1.0.0
    module SupervisorFcgiProgram
      # A `supervisor_fcgi_program` resource to manage Supervisor FCGI programs.
      #
      # @provides supervisor_fcgi_program
      # @action add
      # @action remove
      # @action start
      # @action stop
      # @action restart
      # @example
      #   supervisor_fcgi_program 'myapp' do
      #     command '/usr/bin/myapp --port 80'
      #   end
      class Resource < SupervisorProgram::Resource
        provides(:supervisor_fcgi_program)

        attribute(:socket, kind_of: String, required: true)
        attribute(:socket_mode, kind_of: [String, NilClass, FalseClass])
        attribute(:socket_owner, kind_of: [String, NilClass, FalseClass])

        private

        def program_ini_data
          super.tap do |ini_data|
            ini_data[:socket] = socket
            ini_data[:socket_mode] = socket_mode if socket_mode
            ini_data[:socket_owner] = socket_owner if socket_owner
          end
        end

        def default_config_options
          {ini: {"fcgi-program:#{program_name}" => program_ini_data}}
        end
      end

      # Provider for `supervisor_fcgi_program`.
      #
      # @see Resource
      # @provides supervisor_fcgi_program
      class Provider < SupervisorProgram::Provider
        provides(:supervisor_fcgi_program)
        # This space left intentionally blank, there is no operational difference.
      end
    end
  end
end
