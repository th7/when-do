require 'spec_helper'
require 'when-do/job'

describe When::Job do
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
    let(:job) { When::Job.new(klass: Object, args: ['arg1', 'arg2'], worker_args: { 'some' => 'args' }) }

    context 'scheduling a valid cron' do
      it 'adds data to the schedules hash in redis' do
        job.schedule('test_schedule', '* * * * *')
        expect(redis.hget(When.schedule_key, 'test_schedule')).to eq "{\"some\":\"args\",\"class\":\"Object\",\"cron\":\"* * * * *\",\"args\":[\"arg1\",\"arg2\"]}"
      end
    end

    context 'scheduling an invalid cron' do
      it 'raises a When::InvalidCron error' do
        expect {
          job.schedule('test_schedule', '0 0 0 0 0')
        }.to raise_error When::InvalidCron
      end
    end
  end

  describe '#enqueue_at' do
    let(:now) { Time.now }
    let(:args) { ['arg1', 'arg2', 3, {'more' => 'args'} ] }
    let(:klass) { String }
    let(:job)   { When::Job.new(klass: klass, args: args, worker_args: { 'some' => 'args' }) }

    it 'adds an item to the delayed list' do
      expect { job.enqueue_at(now) }
        .to change { redis.zrange(When.delayed_queue_key, 0, -1).count }
        .from(0).to(1)
    end

    it 'adds the correct score' do
      job.enqueue_at(now)
      score = redis.zrange(When.delayed_queue_key, 0, -1, with_scores: true).first.last
      expect(score).to eq now.to_i.to_f
    end

    it 'adds the correct args' do
      job.enqueue_at(now)
      new_args = JSON.parse(redis.zrange(When.delayed_queue_key, 0, -1).first)['args']
      expect(new_args).to eq args
    end

    it 'adds the correct class' do
      job.enqueue_at(now)
      new_args = JSON.parse(redis.zrange(When.delayed_queue_key, 0, -1).first)['class']
      expect(new_args).to eq klass.name
    end

    it 'adds worker args' do
      job.enqueue_at(now)
      job = JSON.parse(redis.zrange(When.delayed_queue_key, 0, -1).first)
      expect(job['some']).to eq 'args'
    end
  end

  describe '#enqueue' do
    let(:args) { ['arg1', 'arg2', 3, {'more' => 'args'} ] }
    let(:klass) { String }
    let(:job)   { When::Job.new(klass: klass, args: args, worker_args: { 'some' => 'args' }) }

    it 'adds an item to the worker queue' do
      expect { job.enqueue }
        .to change { redis.llen(When.worker_queue_key) }
        .from(0).to(1)
    end

    it 'adds the correct args' do
      job.enqueue
      enqueued_args = JSON.parse(redis.rpop(When.worker_queue_key))['args']
      expect(enqueued_args).to eq args
    end

    it 'adds the correct class' do
      job.enqueue
      enqueued_class = JSON.parse(redis.rpop(When.worker_queue_key))['class']
      expect(enqueued_class).to eq klass.name
    end

    it 'adds worker args' do
      job.enqueue
      job = JSON.parse(redis.rpop(When.worker_queue_key))
      expect(job['some']).to eq 'args'
    end
  end
end
