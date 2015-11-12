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

require 'net/http'
require 'socket'


module PoiseSupervisor
  module Utils
    # Based on https://github.com/puppetlabs/net_http_unix/blob/master/lib/net_x/http_unix.rb
    # Copyright Jeff McCune <jeff@puppetlabs.com>. Used under Apache 2.0 Public License.
    class UnixHTTP < Net::HTTP
      def initialize(address, port=nil)
        super(address, port)
        if address[0] == '/'
          @socket_type = 'unix'
          @socket_path = address
          # Address and port are set to localhost so the HTTP client constructs
          # a HOST request header nginx will accept.
          @address = 'localhost'
          @port = 80
        else
          @socket_type = 'inet'
        end
      end

      def connect
        if @socket_type == 'unix'
          connect_unix
        else
          super
        end
      end

      private

      # connect_unix is an alternative implementation of Net::HTTP#connect specific
      # to the use case of using a Unix Domain Socket.
      def connect_unix
        D "opening connection to #{@socket_path}..."
        s = timeout(@open_timeout) { UNIXSocket.open(@socket_path) }
        D "opened"
        @socket = Net::BufferedIO.new(s)
        @socket.read_timeout = @read_timeout
        @socket.continue_timeout = @continue_timeout
        @socket.debug_output = @debug_output
        on_connect
      end
    end
  end
end
