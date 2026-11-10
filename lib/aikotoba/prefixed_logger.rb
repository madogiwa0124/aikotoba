# frozen_string_literal: true

module Aikotoba
  # NOTE: What Aikotoba.logger returns: the app's logger, with "[Aikotoba]" in front of each
  #       message, so Aikotoba.logger.warn("...") reads like Rails.logger.warn("..."). The app's
  #       logger is looked up on every call, since Rails.logger is set after Aikotoba is loaded
  #       and an app may replace it. A prefix rather than ActiveSupport::TaggedLogging, whose
  #       tagged doesn't work through a BroadcastLogger with more than one logger (it returns an
  #       Array, or runs its block once per logger), nor on a logger the app set up without it.
  class PrefixedLogger
    PREFIX = "[Aikotoba]"
    # NOTE: The same as Logger's: a method for each level, and a ? for each but unknown, which
    #       Logger has no unknown? for.
    LEVELS = %i[debug info warn error fatal unknown].freeze
    PREDICATES = %i[debug? info? warn? error? fatal?].freeze

    def initialize(logger = nil)
      @logger = logger
    end

    LEVELS.each do |level|
      # NOTE: Same arguments as Logger: a message, or a progname and the message as a block. The
      #       message is passed on as a block, so a block message is only built when the level is
      #       enabled.
      define_method(level) do |message_or_progname = nil, &block|
        logger = target
        return true unless logger

        if block
          logger.public_send(level, message_or_progname) { prefixed(block.call) }
        else
          logger.public_send(level) { prefixed(message_or_progname) }
        end
      end
    end

    PREDICATES.each do |predicate|
      define_method(predicate) do
        target&.public_send(predicate) || false
      end
    end

    private

    # NOTE: A String as is, anything else (an exception, say) by inspect, as Logger's default
    #       formatter writes it, so the class of an exception isn't lost.
    def prefixed(message)
      "#{PREFIX} #{message.is_a?(String) ? message : message.inspect}"
    end

    def target
      @logger || (Rails.logger if defined?(Rails) && Rails.respond_to?(:logger))
    end
  end
end
