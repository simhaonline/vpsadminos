module OsCtld
  class Group
    include Lockable
    include CGroupParams

    attr_reader :name, :path

    def initialize(name, load: true, root: false)
      init_lock
      @name = name
      @root = root
      @params = []
      load_config if load
    end

    def id
      @name
    end

    def root?
      @root
    end

    def configure(path, params = [])
      @path = path
      set(params, save: false)
      save_config
    end

    def config_path
      File.join('/', OsCtld::CONF_DS, 'group', "#{id}.yml")
    end

    def cgroup_path
      if root?
        path

      else
        File.join(GroupList.root.path, path)
      end
    end

    def full_cgroup_path(user)
      File.join(cgroup_path, user.name)
    end

    def abs_cgroup_path(subsystem)
      File.join(OsCtld::CGROUP_FS, real_subsystem(subsystem), cgroup_path)
    end

    def userdir(user)
      File.join(user.userdir, name)
    end

    def setup_for?(user)
      Dir.exist?(userdir(user))
    end

    def has_containers?
      ct = ContainerList.get.detect { |ct| ct.group.name == name }
      ct ? true : false
    end

    def containers
      ret = []

      ContainerList.get.each do |ct|
        next if ct.group != self || ret.include?(ct)
        ret << ct
      end

      ret
    end

    def users
      ret = []

      ContainerList.get.each do |ct|
        next if ct.group != self || ret.include?(ct.user)
        ret << ct.user
      end

      ret
    end

    protected
    def load_config
      cfg = YAML.load_file(config_path)

      @path = cfg['path']
      @params = load_params(cfg['params'])
    end

    def save_config
      File.open(config_path, 'w', 0400) do |f|
        f.write(YAML.dump({
          'path' => path,
          'params' => dump_params(params),
        }))
      end

      File.chown(0, 0, config_path)
    end
  end
end