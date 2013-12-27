Gem.find_files("when-do/**/*.rb").each { |path| require path }
require 'redis'
require 'json'

module When
  def self.schedule(name, klass, cron, args=[], key=schedule_key)
    value = {'class' => klass.to_s, 'cron' => cron, 'args' => args}.to_json
    redis.hset(key, name.to_s, value)
  end

  def self.unschedule(name, key=schedule_key)
    redis.hdel(key, name)
  end

  def self.schedule_key
    'when:schedules'
  end

  private

  def self.redis
    @redis ||= Redis.new
  end
end
