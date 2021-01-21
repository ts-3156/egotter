# -*- SkipSchemaAnnotations

module InMemory
  class Client
    def initialize(klass, hostname)
      @klass = klass
      @key_prefix = "#{Rails.env}:#{self.class}:#{@klass}"
      @redis = Redis.client(hostname)
    end

    def ttl
      ::InMemory::TTL.send([:+, :-].shuffle[0], rand(60))
    end

    def read(key)
      @redis.get(db_key(key))
    end

    def write(key, item)
      @redis.setex(db_key(key), ttl, item)
    end

    def delete(key)
      @redis.del(db_key(key))
    end

    private

    def db_key(key)
      "#{@key_prefix}:#{key}"
    end

    module RescueAllRedisErrors
      %i(
        read
        write
        delete
      ).each do |method_name|
        define_method(method_name) do |*args, &blk|
          super(*args, &blk)
        rescue Redis::BaseError => e
          Rails.logger.warn "Rescue all errors klass=#{@klass} method=#{method_name} exception=#{e.inspect} args=#{args.inspect.truncate(100)}"
          Rails.logger.info e.backtrace.join("\n")
          nil
        end
      end
    end
    prepend RescueAllRedisErrors

    module Instrumentation
      %i(
        read
        write
        delete
      ).each do |method_name|
        define_method(method_name) do |*args, &blk|
          message = "#{@klass} #{method_name} by #{args[0]}"
          ApplicationRecord.benchmark(message, level: :info) do
            method(method_name).super_method.call(*args, &blk)
          end
        end
      end
    end
    prepend Instrumentation
  end
end
