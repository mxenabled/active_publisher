module ActivePublisher
  module Async
    class AbstractQueue
      def concat(array)
        fail ::NotImplementedError
      end

      def flush
        fail ::NotImplementedError
      end

      def pop_up_to(n)
        fail ::NotImplementedError
      end

      def push(message)
        fail ::NotImplementedError
      end

      def size
        fail ::NotImplementedError
      end
    end
  end
end
