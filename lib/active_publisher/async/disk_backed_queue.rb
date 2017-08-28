require "pstore"
require "thread"
require "securerandom"

module ActivePublisher
  module Async
    ##
    # This is just a wrapper class. You can use this to turn any AbstractQueue into a disk backed
    # queue. Check out the default options for docs on how to tune this queue wrapper.
    #
    class DiskBackedQueue < ::ActivePublisher::Async::AbstractQueue
      class Page
        attr_reader :file_path

        def initialize(file_path, key_name = nil)
          @file_path = file_path
          @key_name = key_name || :data
          @store = ::PStore.new(file_path)
        end

        # Write to pstore on disk
        def save(data)
          @store.transaction do
            @store[@key_name] = data
            @store.commit
          end

          true
        rescue
          # TODO: Rescue IO errors and return false
          false
        end

        def read
          # TODO: Rescue IO errors and return nil
          # Read from the pstore
          @store.transaction { @store[@key_name] }
        rescue
          nil
        end

        def delete
          # Delete the pstore off disk
          ::File.delete(@file_path) if File.exist?(@file_path)
        rescue ::Errno::ENOENT
          nil
        end
      end

      attr_reader :memory_queue, :size_counter, :options

      DEFAULT_OPTIONS = {
        # The max number of messages you want to keep in memory before beginning paging data.
        # NOTE: Your actual max number of messages is "in_memory_high_watermark" + "page_size".
        :in_memory_high_watermark => 10_000,
        # Number of messages to store in each page file. This will attempt to be as close to this
        # number as possible, but might be fewer.
        :page_size => 1_000,
        # Directory in which you'd like your pages to be stored.
        :db_path => "/tmp",
        # Naming prefix for your page files. NOTE: More data will be appended to make them unique.
        :db_name => "active_publisher.async_queue_disk_cache",
      }

      def initialize(queue, options = {})
        @options = options.merge(DEFAULT_OPTIONS)

        if @options[:in_memory_high_watermark] <= @options[:page_size]
          fail ArgumentError, "In memory limit must be greater than page size!"
        end

        @mutex = ::Mutex.new
        @memory_queue = queue
        @pages_on_disk = fetch_pages_on_disk
      end

      def clear
        # NOTE: This mutex only protects reading/ writing data to disk. It does not protect the underlying
        # queue from being accessed. TO MAKE THIS EFFICIENT, ENSURE NO MORE WRITES HAPPEN BEFORE CLEARING
        # OR THIS MIGHT GET STUCK OR YOU MIGHT END UP WITH MANY SINGLE MESSAGE PAGES. THIS IS ON YOU.
        @mutex.synchronize do
          loop do
            return if @memory_queue.size == 0

            # This method will log errors related to flushing messages.
            _flush_page_to_disk
          end
        end
      end

      def concat(messages)
        response = @memory_queue.concat(messages)
        page_to_disk_if_needed
        response
      end

      def pop_up_to(n)
        attempt_to_load_page_from_disk
        messages = @memory_queue.pop_up_to(n)
        messages
      end

      def push(message)
        response = @memory_queue.push(message)
        page_to_disk_if_needed
        response
      end

      def size
        # We are only concerned about non-paged data. Any data loaded from a page will be added back here.
        @memory_queue.size
      end

    private

      # TODO: We should load more than one page. Maybe load up until 50% of high watermark.
      def attempt_to_load_page_from_disk
        return if @pages_on_disk.empty?
        # NOTE: This we don't load a page only to re-page because we're over the high watermark.
        return if (@memory_queue.size + options[:page_size]) > options[:in_memory_high_watermark]
        @mutex.synchronize do
          # Check these again in case we're fighting for the mutex
          return if @pages_on_disk.empty?
          return if (@memory_queue.size + options[:page_size]) > options[:in_memory_high_watermark]
          page_file_path = @pages_on_disk.pop
          _load_page_from_disk(page_file_path)
        end
      end

      # NOTE: This method must be called from a protected context.
      def _load_page_from_disk(page_file_path)
        page = Page.new(page_file_path)
        messages = page.read
        if messages.nil?
          logger.error "Could not read message on disk for #{page_file_path}. Skipping."
          return
        end

        # We have the messages, so let's queue them up.
        @memory_queue.concat(messages)
      ensure
        page.delete
      end

      def fetch_pages_on_disk
        page_finder_regex = "#{options[:db_name]}.*"
        ::Dir.glob(::File.join(options[:db_path], page_finder_regex))
      end

      def new_page
        page_name = "#{options[:db_name]}.#{::SecureRandom.uuid}"
        page_file_path = ::File.join(options[:db_path], page_name)
        Page.new(page_file_path)
      end

      # TODO: This should probably page until we're about 50% below the high watermark.
      def page_to_disk_if_needed
        loop do
          page_size = options[:page_size]
          in_memory_high_watermark = options[:in_memory_high_watermark]
          # NOTE: It's important to ensure we're at least 1 page over the water mark since we don't stream to disk.
          # If we didn't do this, we could end up with 1 file for each message over the watermark.
          return unless @memory_queue.size >= (in_memory_high_watermark + page_size)
          @mutex.synchronize do
            # Check this again in case we're fighting for the mutex
            return unless @memory_queue.size >= (in_memory_high_watermark + page_size)
            _flush_page_to_disk
          end
        end
      end

      def _flush_page_to_disk
        page_size = options[:page_size]

        # This page size is a best effort page size. The queue might return less than the page size, but we'll page
        # what we get :).
        messages = @memory_queue.pop_up_to(page_size)

        # Save the page to disk. Log if an error occurs and drop messages.
        page = new_page
        unless page.save(messages)
          logger.error "There was an error saving the page to disk. Dropping #{messages.size} messages."
        end

        # Keep a reference to the page
        @pages_on_disk << page.file_path
      end

    end
  end
end
