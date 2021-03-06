require 'osctld/commands/base'

module OsCtld
  class Commands::Container::CGParamList < Commands::Base
    handle :ct_cgparam_list
    include Utils::CGroupParams

    def execute
      ct = DB::Containers.find(opts[:id], opts[:pool])
      return error('container not found') unless ct

      list(ct)
    end
  end
end
