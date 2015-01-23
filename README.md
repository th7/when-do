# When-do

Reads schedules from Redis and moves them onto a Redis list at the correct time.

Supports

* Dynamic cron schedules
* Delayed queueing

Schedules are not cached and can be changed at will. Redundant processes can run without duplication of jobs as long as they point to the same Redis. Jobs will not be double-queued when DST resets time backwards, and will be queued as DST skips over them. Leap seconds are fine.

## Installation

Add this line to your application's Gemfile:

    gem 'when-do'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install when-do

## Usage
From your project's main directory:

    $ when-do -init

Rename the example config and tweak as needed. For example, try setting your ```:worker_queue_key: 'queues:default'``` so Sidekiq picks up your jobs. Use symbols for all keys in the config.

Then run in your console with default config:

    $ when-do

Or start a daemon that uses your config file and writes a pid file.

    $ when-do -d -c 'config/when.yml' -e development

I'd recommend using Monit to manage and monitor daemons. When-do is designed to let a different process handle failure notifications/restarting.

Then, from your app...

Queue a job now:

    When.enqueue(WorkerClass, args: ['array', 'of', 'args'], worker_args: {'retry' => 'false'})

Queue a job later (minute precision):

    When.enqueue_at(Time.now + 60, WorkerClass, args: ['array', 'of', 'args'], worker_args: {'queue' => 'my_other_work_queue'})

Schedule a job (only numbers are supported in cron strings):

    When.schedule('schedule_name', '0 * * * *', WorkerClass, args: ['array', 'of', 'args'], worker_args: {'hash' => 'of_worker_args'})

Unschedule a job:

    When.unschedule('schedule_name')

Clear schedules:

    When.unschedule_all

Check schedules:

    When.schedules

On my 2013 1.3GHz Macbook Air, 100k schedules can be analyzed in <3 seconds.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
