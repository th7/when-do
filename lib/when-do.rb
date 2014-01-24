require 'redis'
require 'json'

module When
  def self.schedule(name, klass, cron, *args)
    value = {'class' => klass.to_s, 'cron' => cron, 'args' => args}.to_json
    redis.hset(schedule_key, name.to_s, value)
  end

  def self.unschedule(name)
    redis.hdel(schedule_key, name.to_s)
  end

  def self.unschedule_all
    redis.del(schedule_key)
  end

  def self.schedules
    schedules = redis.hgetall(schedule_key)
    schedules.each { |k, v| schedules[k] = JSON.parse(v) }
  end

  private

  def self.schedule_key
    'when:schedules'
  end

  def self.redis
    @redis ||= Redis.new
  end
end
