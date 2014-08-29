require 'redis'
require 'json'
require 'yaml'
require 'logger'

module When
  class Error < StandardError; end
  class InvalidCron < Error; end

  DEFAULT_CONFIG = {
    schedule_key:      'when:schedules',
    worker_queue_key:  'when:queue:default',
    delayed_queue_key: 'when:delayed'
  }

  def self.schedule(name, cron, klass, *args)
    raise InvalidCron, "\"#{cron}\" is invalid" unless valid_cron?(cron)
    schedule = {'class' => klass.to_s, 'cron' => cron, 'args' => args}
    redis.hset(schedule_key, name.to_s, schedule.to_json)
    logger.info("Scheduled '#{name}' => #{schedule}.")
  end

  def self.valid_cron?(cron)
    When::Cron.valid?(cron)
  end

  def self.unschedule(name)
    json_sched = redis.hget(schedule_key, name.to_s)
    schedule = JSON.parse(json_sched) if json_sched
    if redis.hdel(schedule_key, name.to_s) > 0
      logger.info("Unscheduled '#{name}' => #{schedule}.")
      true
    else
      logger.warn("Could not unschedule '#{name}'. No schedule by that name was found.")
      false
    end
  end

  def self.unschedule_all
    count = redis.del(schedule_key)
    logger.info("Cleared #{count} schedules.")
    count
  end

  def self.schedules
    schedules = redis.hgetall(schedule_key)
    schedules.each { |k, v| schedules[k] = JSON.parse(v) }
  end

  def self.enqueue_at(time, klass, *args)
    job = { 'jid' => SecureRandom.uuid, 'class' => klass.to_s, 'args' => args }
    if redis.zadd(delayed_queue_key, time.to_i, job.to_json)
      logger.info("Delayed: will enqueue #{job} to run at #{time}.")
      job['jid']
    else
      msg = "Failed to enqueue #{job} to run at #{time}."
      logger.fatal(msg)
      raise msg
    end
  end

  def self.enqueue(klass, *args)
    job = { 'jid' => SecureRandom.uuid, 'class' => klass.to_s, 'args' => args }
    if redis.lpush(worker_queue_key, job.to_json) > 0
      job['jid']
    else
      msg = "Failed to enqueue #{job}."
      logger.fatal(msg)
      raise msg
    end
  end

  def self.redis
    @redis ||= if config[:redis_config_path]
      Redis.new(YAML.load(File.read(config[:redis_config_path])))
    else
      Redis.new
    end
  end

  def self.redis=(redis)
    logger.info("Resetting redis to #{redis.inspect}")
    @redis = redis
  end

  def self.config
    @config ||= DEFAULT_CONFIG
  end

  def self.config=(new_config)
    logger.info("Resetting config to #{new_config.inspect}") if @config
    @config = new_config
  end

  def self.logger
    @logger ||= if config[:log_path]
      Logger.new(config[:log_path], 100, 10_240_000)
    else
      Logger.new(STDOUT)
    end
  end

  def self.logger=(new_logger)
    logger.info("Changing logger to #{new_logger.inspect}")
    @logger = new_logger
  end

  def self.schedule_key
    config[:schedule_key] || 'when:schedules'
  end

  def self.delayed_queue_key
    config[:delayed_queue_key] || 'when:delayed'
  end

  def self.worker_queue_key
    config[:worker_queue_key] || 'when:queue:default'
  end
end
