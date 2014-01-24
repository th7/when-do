require 'spec_helper'

def redis
  @redis ||= Redis.new
end

def key
  'when:test_schedule'
end

describe When do
  before do
    When.stub(:schedule_key).and_return(key)
  end

  after(:all) do
    redis.del(key)
  end

  describe '#schedule' do
    it 'adds data to the schedules hash in redis' do
      When.schedule('test_schedule', Object, '* * * * *', 'arg1', 'arg2')
      expect(redis.hget(key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[\"arg1\",\"arg2\"]}"
    end
  end

  describe '#unschedule' do
    it 'removes data from the schedules hash in redis' do
      When.schedule('test_schedule', Object, '* * * * *')
      expect(redis.hget(key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[]}"
      When.unschedule('test_schedule')
      expect(redis.hget(key, 'test_schedule')).to be_nil
    end
  end
end
