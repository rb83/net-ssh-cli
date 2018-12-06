require "net/ssh/cli/version"
require 'net/ssh'

module Net
  module SSH
    module CLI
      include Net::SSH
      class Error < StandardError
        class Pty < Error; end
        class RequestShell < Error; end
      end

      attr_accessor :options, :ssh, :ssh_options, :channel, :host, :ip, :user, :stdin, :stderr

      def initialize(host, user, **opts)
        @options = opts
        @host = options[:host]
        self.ssh_options = options[:ssh] || {}
      end

      def ssh
        @ssh ||= (ssh_options[:proxy] || Net::SSH.start(ip || host))
      end

      def stdin
        @stdin ||= String.new
      end

      def stderr
        @stderr ||= String.new
      end

      def set_channel #cli_channel
        ssh.open_channel do |chn|
          self.channel = chn
          chn.request_pty do |ch,success|
            raise Error::Pty, "Failed to open ssh pty" unless success
          end
          chn.send_channel_request("shell") do |ch, success|
            raise Error::RequestShell.new("Failed to open ssh shell") unless success
          end
          chn.on_data do |ch,data|
            stdin << data
          end
          chn.on_extended_data do |ch,type,data|
            stderr << data if type == 1
          end
          #chn.on_close { @eof = true }
        end
        ssh.process(0.1)
      end

      def write(content = String.new)
        channel.send_data content
        ssh.process(0.1)
        content
      end

      def read
        ssh.process(0.1)
        pre_buf = stdin
        self.stdin = String.new
        pre_buf
      end

      def read_till(**options)
        while !stdin[/\w+@\w+:/]
          ssh.process(0.1)
        end
        read
      end

      def close
        if ssh
          ssh.cleanup_channel(channel)
          ssh.close unless ssh.channels.any?
        end
      end
  
      def shutdown!
        ssh.shutdown! if ssh
      end
    end
  end
end

class Net::CLI
  include Net::SSH::CLI
end
