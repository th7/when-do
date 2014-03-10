require 'spec_helper'
require 'when-do'

describe When do
  let(:redis) { When.redis }

  before do
    When.logger.level = 5
    When.redis = Redis.new(db: 11)
    redis.flushall
  end

  after do
    redis.flushall
  end

  describe '#schedule' do
    it 'adds data to the schedules hash in redis' do
      When.schedule('test_schedule', '* * * * *',  Object, 'arg1', 'arg2')
      expect(redis.hget(When.schedule_key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[\"arg1\",\"arg2\"]}"
    end
  end

  describe '#unschedule' do
    it 'removes data from the schedules hash in redis' do
      When.schedule('test_schedule', '* * * * *', Object)
      expect(redis.hget(When.schedule_key, 'test_schedule')).to eq "{\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[]}"
      When.unschedule('test_schedule')
      expect(redis.hget(When.schedule_key, 'test_schedule')).to be_nil
    end
  end

  describe '#enqueue_at' do
    let(:now) { Time.now }
    let(:args) { ['arg1', 'arg2', 3, {'more' => 'args'} ] }
    let(:klass) { String }

    it 'adds an item to the delayed list' do
      expect { When.enqueue_at(now, klass) }
        .to change { redis.zrange(When.delayed_queue_key, 0, -1).count }
        .from(0).to(1)
    end

    it 'adds the correct score' do
      When.enqueue_at(now, klass)
      score = redis.zrange(When.delayed_queue_key, 0, -1, with_scores: true).first.last
      expect(score).to eq now.to_i.to_f
    end

    it 'adds the correct args' do
      When.enqueue_at(now, klass, *args)
      new_args = JSON.parse(redis.zrange(When.delayed_queue_key, 0, -1).first)['args']
      expect(new_args).to eq args
    end

    it 'adds the correct class' do
      When.enqueue_at(now, klass, *args)
      new_args = JSON.parse(redis.zrange(When.delayed_queue_key, 0, -1).first)['class']
      expect(new_args).to eq klass.name
    end
  end

  describe '#enqueue' do
    let(:args) { ['arg1', 'arg2', 3, {'more' => 'args'} ] }
    let(:klass) { String }

    it 'adds an item to the worker queue' do
      expect { When.enqueue(klass) }
        .to change { redis.llen(When.worker_queue_key) }
        .from(0).to(1)
    end

    it 'adds the correct args' do
      When.enqueue(klass, *args)
      enqueued_args = JSON.parse(redis.rpop(When.worker_queue_key))['args']
      expect(enqueued_args).to eq args
    end

    it 'adds the correct class' do
      When.enqueue(klass)
      enqueued_class = JSON.parse(redis.rpop(When.worker_queue_key))['class']
      expect(enqueued_class).to eq klass.name
    end
  end
end
