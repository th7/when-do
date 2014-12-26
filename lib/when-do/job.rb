require 'when-do'

module When
  class Job
    attr_reader :klass, :args, :worker_args

    def initialize(klass:, args: [], worker_args: {})
      @klass       = klass
      @args        = args
      @worker_args = worker_args
    end

    def schedule(name, cron)
      When.schedule(name, cron, klass, args: args, worker_args: worker_args)
    end

    def enqueue_at(time)
      When.enqueue_at(time, klass, args: args, worker_args: worker_args)
    end

    def enqueue
      When.enqueue(klass, args: args, worker_args: worker_args  )
    end
  end
end
