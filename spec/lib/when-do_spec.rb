require 'spec_helper'

def redis
  Redis.new
end

def key
  'when:test_schedule'
end

describe When do
  after(:all) do
    redis.del(key)
  end

  describe '#schedule' do
    it 'adds data to the schedules hash in redis' do
      When.schedule('test_schedule', Object, '* * * * *', [], key)
      expect(redis.hget(key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[]}"
    end
  end

  describe '#unschedule' do
    it 'removes data from the schedules hash in redis' do
      When.schedule('test_schedule', Object, '* * * * *', [], key)
      expect(redis.hget(key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[]}"
      When.unschedule('test_schedule', key)
      expect(redis.hget(key, 'test_schedule')).to be_nil
    end
  end
end
