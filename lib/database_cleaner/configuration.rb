require 'database_cleaner/base'
require 'forwardable'

module DatabaseCleaner

  class NoORMDetected < StandardError; end
  class UnknownStrategySpecified < ArgumentError; end

  class Cleaners < Hash
    # FIXME this method conflates creation with lookup... both a command and a query. yuck.
    def [](orm, opts = {})
      raise NoORMDetected unless orm
      fetch([orm, opts]) { add_cleaner(orm, opts) }
    end 

    # TODO privatize in 2.0
    def add_cleaner(orm, opts = {})
      self[[orm, opts]] = ::DatabaseCleaner::Base.new(orm, opts)
    end
  end

  class Configuration
    def initialize
      @cleaners ||= Cleaners.new
    end

    extend Forwardable
    delegate [:[], :add_cleaner] => :cleaners

    attr_accessor :app_root, :logger, :cleaners

    def app_root
      @app_root ||= Dir.pwd
    end

    def logger
      @logger ||= Logger.new(STDOUT).tap { |l| l.level = Logger::ERROR }
    end

    def strategy=(stratagem)
      connections.each { |connect| connect.strategy = stratagem }
      remove_duplicates
    end

    def orm=(orm)
      connections.each { |connect| connect.orm = orm }
      remove_duplicates
    end

    def start
      connections.each { |connection| connection.start }
    end

    def clean
      connections.each { |connection| connection.clean }
    end

    def cleaning(&inner_block)
      connections.inject(inner_block) do |curr_block, connection|
        proc { connection.cleaning(&curr_block) }
      end.call
    end

    def clean_with(*args)
      connections.each { |connection| connection.clean_with(*args) }
    end

    # TODO deprecate and remove the following aliases:

    alias clean! clean
    alias clean_with! clean_with

    # TODO deprecate and then privatize the following methods:

    def init_cleaners
      $stderr.puts "Calling `DatabaseCleaner.init_cleaners` is deprecated, and will be removed in database_cleaner 2.0 with no replacement."
    end

    def connections
      if called_externally?(caller)
        $stderr.puts "Calling `DatabaseCleaner.connections` is deprecated, and will be removed in database_cleaner 2.0. Use `DatabaseCleaner.cleaners`, instead."
      end
      add_cleaner(:autodetect) if @cleaners.none?
      @cleaners.values
    end

    def remove_duplicates
      @cleaners = @cleaners.reduce({}) do |cleaners, (key, value)|
        cleaners[key] = value unless cleaners.values.include?(value)
        cleaners
      end
    end

    private

    def called_externally?(caller)
      __FILE__ != caller.first.split(":").first
    end
  end
end
