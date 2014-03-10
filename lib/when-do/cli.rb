require 'when-cron'
require 'json'
require 'yaml'
require 'redis'

module When
  class CLI
    CANONICAL_KEYS = {
      :sk => :schedule_key,
      :wq => :worker_queue_key,
      :dq => :delayed_queue_key,
      :lp => :log_path,
      :ll => :log_level,
      :c  => :config_path,
      :rc => :redis_config_path,
      :d  => :daemonize,
      :e  => :environment,
      :pf => :pid_file_path
    }

    def init
      cl_opts = canonicalize_keys(argv_to_hash)
      copy_example_config if cl_opts.has_key? :init
      @options = merge_redis_config_file(merge_config_file(cl_opts))
    end

    def options
      @options ||= init
    end

    private

    def copy_example_config
      bin_path = File.expand_path(File.dirname(__FILE__))
      system('mkdir config')
      if system("cp #{bin_path}/../../config/when.yml.example config/")
        puts "Example config copied to /config/when.yml.example"
      else
        puts 'Failed to copy example config.'
      end
      exit
    end

    def argv
      ARGV
    end

    def argv_to_hash
      argv.each.with_index.inject({}) do |opts, (arg, i)|
        if arg[0] == '-'
          values = argv_values_for(i)
          key = arg.gsub(/\A-*/, '').to_sym
          if values.count <= 1
            opts[key] = values.first
          else
            opts[key] = values
          end
        end
        opts
      end
    end

    def argv_values_for(key_index)
      first_val = key_index + 1
      argv[first_val..-1].each_with_index do |arg, i|
        return argv[first_val...first_val + i] if arg[0] == '-'
      end
    end

    def canonicalize_keys(commandline_opts)
      commandline_opts.inject({}) do |opts, (k, v)|
        if new_key = CANONICAL_KEYS[k]
          opts[new_key] = v
        else
          opts[k] = v
        end
        opts
      end
    end

    def merge_config_file(commandline_opts)
      config_path = commandline_opts[:config_path]
      file_config = load_opts(config_path)
      env         = commandline_opts[:environment] || :development
      file_opts   = file_config[env.to_sym]        || {}
      file_opts.merge(commandline_opts)
    end

    def merge_redis_config_file(merged_opts)
      merged_opts.merge(redis_opts: load_opts(merged_opts[:redis_config_path]))
    end

    def load_opts(path)
      if path
        YAML.load(File.read(path))
      else
        {}
      end
    end
  end
end
