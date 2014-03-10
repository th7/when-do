require 'spec_helper'
require 'when-do/do'
require 'when-do'

describe When::Do do
  let(:test_redis_index) { 11 }
  let(:redis) { Redis.new(db: test_redis_index) }
  let(:when_do) { When::Do.new(redis_opts: {db: test_redis_index}) }
  let(:started_at) { Time.now }

  before do
    When.logger.level = 5
    when_do.logger.level = 5
    When.redis = redis
    redis.flushall
  end

  after do
    redis.flushall
  end

  describe '#running?' do
    let(:day_key) { when_do.build_day_key(started_at) }
    let(:min_key) { when_do.build_min_key(started_at) }

    context 'the corresponding day hash and minute key exist in redis' do
      before do
        redis.hset(day_key, min_key, 't')
      end

      it 'returns true' do
        expect(when_do.running?(started_at)).to be_true
      end
    end

    context 'the corresponding day hash and minute key do not exist in redis' do
      it 'sets the day hash and minute key' do
        expect { when_do.running?(started_at) }.to change { redis.hget(day_key, min_key) }.from(nil).to be_true
      end

      it 'returns false' do
        expect(when_do.running?(started_at)).to be_false
      end
    end
  end

  describe '#queue_scheduled' do
    context 'a scheduled item has a matching cron' do
      let(:args) { ['arg1', 'arg2', 3, { 'more' => 'args' }] }
      let(:klass) { String }
      before do
        When.schedule('test schedule', '* * * * *', klass, *args)
      end

      it 'drops a job onto the queue' do
        expect { when_do.queue_scheduled(started_at) }
          .to change { redis.lpop(when_do.worker_queue_key) }
          .from(nil)
          .to be_true
      end

      it 'includes the correct arguments' do
        when_do.queue_scheduled(started_at)
        job = JSON.parse(redis.lpop(when_do.worker_queue_key))
        expect(job['args']).to eq args
      end

      it 'includes the correct class' do
        when_do.queue_scheduled(started_at)
        job = JSON.parse(redis.lpop(when_do.worker_queue_key))
        expect(job['class']).to eq klass.name
      end
    end

    context 'a scheduled item does not have a matching cron' do
      before do
        When.schedule('test schedule', String, '0 0 0 0 0')
      end

      it 'does not add an item to the queue' do
        expect { when_do.queue_scheduled(started_at) }
          .not_to change { redis.lpop(when_do.worker_queue_key) }
          .from(nil)
      end
    end
  end

  describe '#queue_delayed' do
    context 'a delayed item is due to be queue' do
      let(:args) { ['arg1', 'arg2', 3, { 'more' => 'args' }] }
      let(:klass) { String }
      before do
        When.enqueue_at(started_at - 1, String, *args)
      end

      it 'drops a job onto the queue' do
        expect { when_do.queue_delayed(started_at) }
          .to change { redis.lpop(when_do.worker_queue_key) }
          .from(nil)
          .to be_true
      end

      it 'includes the correct arguments' do
        when_do.queue_delayed(started_at)
        job = JSON.parse(redis.lpop(when_do.worker_queue_key))
        expect(job['args']).to eq args
      end

      it 'includes the correct class' do
        when_do.queue_delayed(started_at)
        job = JSON.parse(redis.lpop(when_do.worker_queue_key))
        expect(job['class']).to eq klass.name
      end
    end

    context 'a delayed item is not yet due to be queued' do
      before do
        When.enqueue_at(started_at + 1, String)
      end

      it 'does not add an item to the queue' do
        expect { when_do.queue_delayed(started_at) }
          .not_to change { redis.lpop(when_do.worker_queue_key) }
          .from(nil)
      end
    end
  end

  describe '#enqueue' do
    it 'places jobs onto the work queue' do
      expect { when_do.enqueue(['junk', 'jobs']) }
        .to change { redis.llen(when_do.worker_queue_key) }
        .from(0)
        .to(2)
    end
  end
end
