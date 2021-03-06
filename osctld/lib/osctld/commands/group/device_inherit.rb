require 'osctld/commands/logged'

module OsCtld
  class Commands::Group::DeviceInherit < Commands::Logged
    handle :group_device_inherit

    include OsCtl::Lib::Utils::Log
    include Utils::Devices

    def find
      grp = DB::Groups.find(opts[:name], opts[:pool])
      grp || error!('group not found')
    end

    def execute(grp)
      manipulate(grp) do
        error!('the root group cannot inherit devices') if grp.root?

        inherit(grp)
      end
    end
  end
end
