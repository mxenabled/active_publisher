module ActivePublisher
  module MultiOpQueue
    # Original Queue implementation from Ruby-2.0.0
    # https://github.com/ruby/ruby/blob/ruby_2_0_0/lib/thread.rb
    #
    # This class provides a way to synchronize communication between threads.
    #
    # Example:
    #
    #   require 'thread'
    #
    #   queue = Queue.new
    #
    #   producer = Thread.new do
    #     5.times do |i|
    #       sleep rand(i) # simulate expense
    #       queue << i
    #       puts "#{i} produced"
    #     end
    #   end
    #
    #   consumer = Thread.new do
    #     5.times do |i|
    #       value = queue.pop
    #       sleep rand(i/2) # simulate expense
    #       puts "consumed #{value}"
    #     end
    #   end
    #
    #   consumer.join
    #
    class Queue
      #
      # Creates a new queue.
      #
      def initialize
        @que = []
        @num_waiting = 0
        @mutex = Mutex.new
        @cond = ConditionVariable.new
      end

      #
      # Concatenates +ary+ onto the queue.
      #
      def concat(ary)
        handle_interrupt do
          @mutex.synchronize do
            @que.concat ary
            @cond.signal
          end
        end
      end

      #
      # Pushes +obj+ to the queue.
      #
      def push(obj)
        handle_interrupt do
          @mutex.synchronize do
            @que.push obj
            @cond.signal
          end
        end
      end

      #
      # Alias of push
      #
      alias << push

      #
      # Alias of push
      #
      alias enq push

      #
      # Retrieves data from the queue.  If the queue is empty, the calling thread is
      # suspended until data is pushed onto the queue.  If +non_block+ is true, the
      # thread isn't suspended, and an exception is raised.
      #
      def pop(non_block=false)
        handle_interrupt do
          @mutex.synchronize do
            while true
              if @que.empty?
                if non_block
                  raise ThreadError, "queue empty"
                else
                  begin
                    @num_waiting += 1
                    @cond.wait @mutex
                  ensure
                    @num_waiting -= 1
                  end
                end
              else
                return @que.shift
              end
            end
          end
        end
      end

      #
      # Alias of pop
      #
      alias shift pop

      #
      # Alias of pop
      #
      alias deq pop

      #
      # Retrieves data from the queue and returns array of contents.
      # If +num_to_pop+ are available in the queue then multiple elements are returned in array response
      # If the queue is empty, the calling thread is
      # suspended until data is pushed onto the queue.  If +non_block+ is true, the
      # thread isn't suspended, and an exception is raised.
      #
      def pop_up_to(num_to_pop = 1, opts = {})
        case opts
        when TrueClass, FalseClass
          non_bock = opts
        when Hash
          timeout = opts.fetch(:timeout, nil)
          non_block = opts.fetch(:non_block, false)
        end

        handle_interrupt do
          @mutex.synchronize do
            while true
              if @que.empty?
                if non_block
                  raise ThreadError, "queue empty"
                else
                  begin
                    @num_waiting += 1
                    @cond.wait(@mutex, timeout)
                    return nil if @que.empty?
                  ensure
                    @num_waiting -= 1
                  end
                end
              else
                return @que.shift(num_to_pop)
              end
            end
          end
        end
      end

      #
      # Returns +true+ if the queue is empty.
      #
      def empty?
        @que.empty?
      end

      #
      # Removes all objects from the queue.
      #
      def clear
        @que.clear
      end

      #
      # Returns the length of the queue.
      #
      def length
        @que.length
      end

      #
      # Alias of length.
      #
      alias size length

      #
      # Returns the number of threads waiting on the queue.
      #
      def num_waiting
        @num_waiting
      end

      private

      def handle_interrupt
        @handle_interrupt = Thread.respond_to?(:handle_interrupt) if @handle_interrupt.nil?

        if @handle_interrupt
          Thread.handle_interrupt(StandardError => :on_blocking) do
            yield
          end
        else
          yield
        end
      end
    end
  end

end
