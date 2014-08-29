require 'when-cron'
require 'json'
require 'redis'
require 'logger'

module When
  class Do
    attr_reader :opts, :schedule_key, :worker_queue_key, :delayed_queue_key, :redis, :logger, :pid_file_path

    def initialize(opts={})
      @opts   = opts
      @logger = init_logger(opts[:log_path], opts[:log_level])

      Process.daemon(true) if opts.has_key?(:daemonize)

      @pid_file_path = opts[:pid_file_path]
      if pid_file_path
        File.open(pid_file_path, 'w') { |f| f.write(Process.pid) }
      end

      redis_opts         = opts[:redis_opts]        || {}
      @redis             = Redis.new(redis_opts)

      @schedule_key      = opts[:schedule_key]      || 'when:schedules'
      @worker_queue_key  = opts[:worker_queue_key]  || 'when:queue:default'
      @delayed_queue_key = opts[:delayed_queue_key] || 'when:delayed'
    end

    def start_loop
      logger.info("Starting...")
      logger.info { "Schedule key: '#{schedule_key}', worker queue key: '#{worker_queue_key}', delayed queue key: '#{delayed_queue_key}'" }
      logger.info { "PID file: #{pid_file_path}" } if pid_file_path

      Signal.trap('USR1') { @logger = init_logger(opts[:log_path], opts[:log_level]) }

      loop do
        sleep_until_next_minute
        logger.debug { "Using #{`ps -o rss -p #{Process.pid}`.chomp.split("\n").last.to_i} kb of memory." }
        analyze_in_child_process
      end

    rescue SystemExit => e
      raise e

    rescue SignalException => e
      logger.info(e.inspect)
      File.delete(pid_file_path) if pid_file_path
      raise e

    rescue Exception => e
      ([e.inspect] + e.backtrace).each { |line| logger.fatal(line) }
      raise e
    end

    def analyze_in_child_process
      if pid = fork
        Thread.new {
          pid, status = Process.wait2(pid)
          if status.exitstatus != 0
            raise "Child (pid: #{pid} exited with non-zero status. Check logs."
          end
        }.abort_on_exception = true
      else
        ['HUP', 'INT', 'TERM', 'QUIT'].each { |sig| Signal.trap(sig) { }}
        analyze(Time.now)
        exit
      end
    end

    def analyze(started_at)
      if running?(started_at)
        logger.info('Another process is already analyzing.')
      else
        analyze_dst(started_at) if dst_forward?(started_at)
        logger.debug { "Analyzing #{started_at}." }
        queue_scheduled(started_at)
        queue_delayed(started_at)
      end
    end

    def running?(started_at)
      day_key = build_day_key(started_at)
      min_key = build_min_key(started_at)

      logger.debug { "Checking Redis using day_key: '#{day_key}' and min_key: '#{min_key}'"}
      check_and_set_analyzed = redis.multi do
        redis.hget(day_key, min_key)
        redis.hset(day_key, min_key, 't')
        redis.expire(day_key, 60 * 60 * 24)
      end

      check_and_set_analyzed[0]
    end

    def dst_forward?(started_at)
      started_at.hour - (started_at - 60).hour == 2
    end

    def analyze_dst(started_at)
      logger.info { "DST forward shift detected. Triggering analysis for #{started_at.hour - 1}:00 through #{started_at.hour - 1}:59"}
      skipped_time = Time.new(started_at.year, started_at.month, started_at.day, started_at.hour - 1, 0, 0, started_at.utc_offset - 3600)
      (0..59).each do |min|
        analyze(skipped_time + min * 60)
      end
    end

    def build_day_key(started_at)
      "#{schedule_key}:#{started_at.to_s.split(' ')[0]}"
    end

    def build_min_key(started_at)
      "#{started_at.hour}:#{started_at.min}"
    end

    def queue_scheduled(started_at)
      schedules = redis.hvals(schedule_key)
      logger.info("Analyzing #{schedules.count} schedules.")
      scheduled_jobs = schedules.inject([]) do |jobs, s|
        schedule = JSON.parse(s)
        if cron = When::Cron.valid(schedule['cron'])
          if cron == started_at
            jobs << { 'jid' => SecureRandom.uuid, 'class' => schedule['class'], 'args' => schedule['args'] }.to_json
          end
        else
          logger.error { "Could not interpret cron for #{schedule.inspect}" }
        end
        jobs
      end
      logger.debug { "Found #{scheduled_jobs.count} schedules due to be queued." }
      enqueue(scheduled_jobs) if scheduled_jobs.any?
    end

    def queue_delayed(started_at)
      logger.info("Checking for delayed jobs.")
      delayed_jobs = redis.multi do
        redis.zrevrangebyscore(delayed_queue_key, started_at.to_i, '-inf')
        redis.zremrangebyscore(delayed_queue_key, '-inf', started_at.to_i)
      end[0]
      logger.debug { "Found #{delayed_jobs.count} delayed jobs." }
      enqueue(delayed_jobs) if delayed_jobs.any?
    end

    def enqueue(jobs)
      jobs.each do |job|
        logger.info("Queueing: #{job}")
      end
      success = redis.lpush(worker_queue_key, jobs)
      unless  success > 0
        raise "Failed to queue all jobs. Redis returned #{success}."
      end
    end

    private

    def sleep_until_next_minute
      to_sleep = 62 - Time.now.sec # handle up to 2 leap seconds
      logger.debug { "Sleeping #{to_sleep} seconds."}
      sleep(to_sleep)
    end

    def init_logger(log_path, log_level)
      logger = if log_path
        Logger.new(log_path)
      else
        Logger.new(STDOUT)
      end
      logger.level = log_level.to_i || 1
      logger
    end
  end
end
