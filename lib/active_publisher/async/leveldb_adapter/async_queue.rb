module ActivePublisher
  module Async
    module LeveldbAdapter
      class AsyncQueue
        QUEUE_SIZE_KEY = "q!size"
        QUEUE_MESSAGE_PREFIX = "m!"
        MAX_MESSAGE_RETRIES = 10

        attr_accessor :back_pressure_strategy,
          :max_queue_size,
          :supervisor_interval

        attr_reader :consumer, :supervisor, :size

        # This is to keep metrics working. The "queue" is a ref to ourself.
        attr_reader :queue


        def self.db_full_path
          # NOTE: This should be unique to each process since we can't share the DB
          # between processes.
          ::ENV.fetch("ACTIVE_PUBLISHER_LEVELDB_DB_PATH", "/tmp/active_publisher-async-1.db")
        end

        def initialize(drop_messages_when_queue_full, max_queue_size, supervisor_interval)
          @back_pressure_strategy = back_pressure_strategy
          @queue = self
          @drop_messages_when_queue_full = drop_messages_when_queue_full
          @supervisor_interval = supervisor_interval
          @max_queue_size = max_queue_size
          @mutex = Mutex.new
          @db = ::LevelDB::DB.new(self.class.db_full_path)

          # Load defaults
          @size = @db.get(QUEUE_SIZE_KEY).to_i

          # Let's rock!
          create_and_supervise_consumer!
        end

        def create_and_supervise_consumer!
          @consumer = ::ActivePublisher::Async::LeveldbAdapter::ConsumerThread.new(self)
          @supervisor = ::Thread.new do
            loop do
              unless consumer.alive?
                consumer.kill
                @consumer = ::ActivePublisher::Async::LeveldbAdapter::ConsumerThread.new(self)
              end

              # Notify the current queue size.
              ::ActiveSupport::Notifications.instrument "async_queue_size.active_publisher", size

              # Pause before checking the consumer again.
              sleep supervisor_interval
            end
          end
        end

        def create_prefix_range(prefix)
          limit = ""
          i = prefix.size - 1
          while i >= 0
            c = prefix[i].ord
            if c < 0xFF
              limit = " " * (i + 1)
              limit[i] = (c + 1).chr
            end
            i -= 1
          end
          [prefix, limit]
        end

        def delete(key)
          @mutex.synchronize do
            return unless @db.has_key?(key)

            @db.batch do |batch|
              batch.put(QUEUE_SIZE_KEY, @size -= 1)
              batch.delete(key)
            end
          end
        end

        def empty?
          size == 0
        end

        def next_batch_with_prefix(prefix, n)
          batch = []
          @db.range(*create_prefix_range(prefix)) do |k, v|
            break if batch.size >= n
            batch << [k, v]
          end
          batch
        end

        def next_batch_of_messages(n)
          next_batch_with_prefix(QUEUE_MESSAGE_PREFIX, n).map do |key, payload|
            [key, ::ActivePublisher::Async::LeveldbAdapter::Message.from_json(payload)]
          end
        end

        def next_message_key(time = nil)
          time ||= ::Time.now
          time.strftime("#{QUEUE_MESSAGE_PREFIX}%s%5N")
        end

        def push(message)
          if size >= max_queue_size
            case back_pressure_strategy
            when :drop
              ::ActiveSupport::Notifications.instrument "message_dropped.active_publisher"
              return
            when :raise
              ::ActiveSupport::Notifications.instrument "message_dropped.active_publisher"
              fail ::ActivePublisher::Async::InMemoryAdapter::UnableToPersistMessageError, "Queue is full, messages will be dropped."
            when :wait
              ::ActiveSupport::Notifications.instrument "wait_for_async_queue.active_publisher" do
                # This is a really crappy way to wait
                sleep 0.01 until size < max_queue_size
              end
            end
          end

          unless message.is_a?(::ActivePublisher::Async::LeveldbAdapter::Message)
            fail ::ActivePublisher::UnknownMessageClassError, "Leveldb async queue only works with ActivePublisher::Async::LeveldbAdapter::Message"
          end

          @mutex.synchronize do
            @db.batch do |batch|
              payload = message.to_json
              batch.put(QUEUE_SIZE_KEY, @size += 1)
              batch.put(next_message_key, payload)
            end
          end
          true
        end

        def retry(key, message)
          return delete(key) if message.retries > MAX_MESSAGE_RETRIES

          offset = (message.retries ** 4) + 15 + (rand(30) * (message.retries + 1))
          message.retries += 1
          payload = message.to_json
          next_attempt_at = ::Time.now + offset
          @db.batch do |batch|
            batch.put(queue.next_message_key(next_attempt_at), payload)
            batch.delete(key)
          end
        end

      end
    end
  end
end
