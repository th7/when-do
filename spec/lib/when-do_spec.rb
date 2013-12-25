require 'spec_helper'

describe When do
  let(:redis) { Redis.new }

  describe '#schedule' do
    it 'adds data to the schedules hash in redis' do
      When.schedule('test_schedule', Object, '* * * * *')
      expect(redis.hget(When.schedule_key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":{}}"
      redis.del(When.schedule_key)
    end
  end

  describe '#unschedule' do
    it 'removes data from the schedules hash in redis' do
      When.schedule('test_schedule', Object, '* * * * *')
      expect(redis.hget(When.schedule_key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":{}}"
      When.unschedule('test_schedule')
      expect(redis.hget(When.schedule_key, 'test_schedule')).to be_nil
      redis.del(When.schedule_key)
    end
  end
end
