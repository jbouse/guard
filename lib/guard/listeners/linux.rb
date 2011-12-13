module Guard

  # Listener implementation for Linux `inotify`.
  #
  class Linux < Listener

    # Initialize the Listener.
    #
    def initialize(*)
      super
      @inotify = INotify::Notifier.new
      @files   = []
      @latency = 0.5
    end

    # Start the listener.
    #
    def start
      @stop = false
      super
      watch_change unless watch_change?
    end

    # Stop the listener.
    #
    def stop
      super
      @stop = true
    end

    # Check if the listener is usable on the current OS.
    #
    # @return [Boolean] whether usable or not
    #
    def self.usable?(no_vendor = false)
      return false unless RbConfig::CONFIG['target_os'] =~ /linux/i

      $LOAD_PATH << File.expand_path('../../../vendor/linux/lib', __FILE__) unless no_vendor
      require 'rb-inotify'
      true
    rescue LoadError
      false
    end

    private

    # Get the listener worker.
    #
    def worker
      @inotify
    end

    # Watch the given directory for file changes.
    #
    # @param [String] directory the directory to watch
    #
    def watch(directory)
      worker.watch(directory, :recursive, :attrib, :create, :move_self, :close_write) do |event|
        unless event.name == "" # Event on root directory
          @files << event.absolute_name
        end
      end
    rescue Interrupt
    end

    # Test if inotify is watching for changes.
    #
    # @return [Boolean] whether inotify is active or not
    #
    def watch_change?
      !!(defined? @watch_change and @watch_change)
    end

    # Watch for file system changes.
    #
    def watch_change
      @watch_change = true
      until @stop
        if RbConfig::CONFIG['build'] =~ /java/ || IO.select([worker.to_io], [], [], @latency)
          break if @stop

          sleep(@latency)
          worker.process

          files = modified_files(@files.shift(@files.size).map { |f| File.dirname(f) }.uniq)
          @callback.call(files) unless files.empty?
        end
      end
      @watch_change = false
    end

  end
end
