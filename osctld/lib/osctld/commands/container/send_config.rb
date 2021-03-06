require 'osctld/commands/base'
require 'tempfile'

module OsCtld
  class Commands::Container::SendConfig < Commands::Base
    handle :ct_send_config

    include OsCtl::Lib::Utils::Send

    def execute
      ct = DB::Containers.find(opts[:id], opts[:pool])
      error!('container not found') unless ct

      manipulate(ct) do
        next error('this container is already being sent') if ct.send_log

        ctid = make_ctid(ct)

        f = Tempfile.open("ct-#{ct.id}-skel")
        export(ct, f, ctid: ctid, network_interfaces: opts[:network_interfaces])
        f.seek(0)

        m_opts = {
          ctid: ctid,
          port: opts[:port] || 22,
          dst: opts[:dst],
        }

        ssh = send_ssh_cmd(
          ct.pool.send_receive_key_chain,
          m_opts,
          ['receive', 'skel']
        )

        IO.popen("exec #{ssh.join(' ')}", 'r+') do |io|
          io.write(f.readpartial(16*1024)) until f.eof?
        end

        f.close
        f.unlink

        if $?.exitstatus == 0
          ct.open_send_log(:source, m_opts)
          ok
        else
          error('send config failed')
        end
      end
    end

    protected
    # @param ct [Container]
    # @param io [IO]
    # @param opts [Hash]
    # @option opts [String] :ctid
    # @option opts [Boolean] :network_interfaces
    def export(ct, io, opts = {})
      exporter = OsCtl::Lib::Exporter::Zfs.new(ct, io)
      exporter.dump_metadata('skel', id: opts[:ctid] || ct.id)
      exporter.dump_configs do |dump|
        dump.user(File.read(ct.user.config_path))
        dump.group(File.read(ct.group.config_path))

        ct_cfg = ct.dump_config
        ct_cfg.delete('net_interfaces') if !opts[:network_interfaces]
        dump.container(YAML.dump(ct_cfg))
      end
      exporter.dump_user_hook_scripts(Container::Hook.hooks)
      exporter.close
    end

    def make_ctid(ct)
      id = opts[:as_id] || ct.id

      if opts[:to_pool]
        [opts[:to_pool], id].join(':')
      else
        id
      end
    end
  end
end
