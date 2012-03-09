require 'test/unit'
require 'redis'

require 'newrelic_redis/instrumentation'

class TestNewRelicRedis < Test::Unit::TestCase
  include NewRelic::Agent::Instrumentation::ControllerInstrumentation

  module StubProcess
    def establish_connection
    end

    def read(*args)
    end

    def process(*args)
      @process_args = args
    end

    attr_reader :process_args

  end

  def setup
    NewRelic::Agent.manual_start
    @engine = NewRelic::Agent.instance.stats_engine
    @engine.clear_stats

    @redis = Redis.new :path => "/tmp/redis"
    @client = @redis.client
    class << @client
      include StubProcess
    end
  end

  def assert_metrics(*m)
    assert_equal m.sort, @engine.metrics.sort
  end

  def test_call
    @redis.hgetall "foo"
    assert_equal [[[:hgetall, "foo"]]], @client.process_args
    assert_metrics "Database/Redis/HGETALL", "Database/Redis/allOther"
  end

  def test_call_pipelined
    @redis.pipelined do
      @redis.hgetall "foo"
      @redis.inc "bar"
    end

    assert_equal [[[:hgetall, "foo"], [:inc, "bar"]]], @client.process_args
    assert_metrics "Database/Redis/Pipelined/HGETALL",
                   "Database/Redis/Pipelined/INC",
                   "Database/Redis/Pipelined",
                   "Database/Redis/allOther"
  end
end