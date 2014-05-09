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
        When.schedule('test schedule', '0 0 0 0 0', String)
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

  describe '#dst_forward?' do
    context 'started_at is the minute after dst skips forward' do
      let(:started_at) { Time.new(2014, 3, 9, 3) }

      it 'returns true' do
        expect(when_do.dst_forward?(started_at)).to eq true
      end
    end

    context 'started_at is the minute before dst skips forward' do
      let(:started_at) { Time.new(2014, 3, 9, 1, 59) }

      it 'returns false' do
        expect(when_do.dst_forward?(started_at)).to eq false
      end
    end

    context 'started_at is the minute after dst skips backward' do
      let(:started_at) { Time.new(2014, 11, 2, 1) }

      it 'returns false' do
        expect(when_do.dst_forward?(started_at)).to eq false
      end
    end

    context 'started_at is the minute before dst skips backward' do
      let(:started_at) { Time.new(2014, 11, 2, 0, 59) + 3600 }

      it 'returns false' do
        expect(when_do.dst_forward?(started_at)).to eq false
      end
    end
  end

  describe '#analyze_dst' do
    it 'calls analyze for each minute of the hour before started_at' do
      hour_before = Time.new(started_at.year, started_at.month, started_at.day, started_at.hour - 1, 0, 0, started_at.utc_offset - 3600)
      (0..59).each do |min|
        expect(when_do).to receive(:analyze).with(hour_before + min * 60).ordered
      end
      when_do.analyze_dst(started_at)
    end
  end

  describe '#analyze' do
    before do
      when_do.stub(:queue_scheduled)
      when_do.stub(:queue_delayed)
    end

    context '#running? is false' do
      before do
        when_do.stub(:running?).with(started_at).and_return false
      end

      it 'calls queue_scheduled' do
        expect(when_do).to receive(:queue_scheduled).with(started_at)
        when_do.analyze(started_at)
      end

      it 'calls queue_delayed' do
        expect(when_do).to receive(:queue_delayed).with(started_at)
        when_do.analyze(started_at)
      end

      context '#dst_forward? is true' do
        before do
          when_do.stub(:dst_forward?).with(started_at).and_return true
        end

        it 'calls analyze_dst' do
          expect(when_do).to receive(:analyze_dst).with(started_at)
          when_do.analyze(started_at)
        end
      end

      context '#dst_forward? is false' do
        before do
          when_do.stub(:dst_forward?).with(started_at).and_return false
        end

        it 'does not call analyze_dst' do
          expect(when_do).not_to receive(:analyze_dst).with(started_at)
          when_do.analyze(started_at)
        end
      end
    end
  end
end
