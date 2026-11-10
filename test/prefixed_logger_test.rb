# frozen_string_literal: true

require "test_helper"

class Aikotoba::PrefixedLoggerTest < ActiveSupport::TestCase
  def setup
    @io = StringIO.new
    @logger = Aikotoba::PrefixedLogger.new(ActiveSupport::Logger.new(@io))
  end

  test "it answers the same level methods and predicates as Logger, unknown? excluded" do
    own = Aikotoba::PrefixedLogger.public_instance_methods(false)
    assert_equal ::Logger::SEV_LABEL.map { |label| label.downcase.sub("any", "unknown").to_sym }, Aikotoba::PrefixedLogger::LEVELS
    assert_empty own - ::Logger.public_instance_methods, "every method it defines exists on Logger"
    assert_empty %i[debug? info? warn? error? fatal?] - own
    Aikotoba::PrefixedLogger::PREDICATES.each { |predicate| assert_includes [true, false], @logger.public_send(predicate) }
  end

  test "every level prefixes its message, given as an argument or a block" do
    @logger.warn("as an argument")
    @logger.error { "as a block" }
    assert_equal ["[Aikotoba] as an argument\n", "[Aikotoba] as a block\n"], @io.string.lines
  end

  test "an exception is written by inspect, keeping its class, as Logger writes it" do
    @logger.error(RuntimeError.new("boom"))
    assert_equal "[Aikotoba] #<RuntimeError: boom>\n", @io.string
  end

  test "an argument given with a block is the progname, as with Logger" do
    progname = nil
    @logger.instance_variable_get(:@logger).formatter = lambda do |_severity, _time, name, message|
      progname = name
      "#{message}\n"
    end
    @logger.info("Aikotoba::Recovery") { "sent" }
    assert_equal "Aikotoba::Recovery", progname
    assert_equal "[Aikotoba] sent\n", @io.string
  end

  test "a block is only run when its level is enabled" do
    @logger.instance_variable_get(:@logger).level = :warn
    @logger.debug { flunk "the block ran for a disabled level" }
    assert_not @logger.debug?
    assert @logger.warn?
    assert_empty @io.string
  end

  test "Aikotoba.logger writes to whatever Rails.logger is at the time of the call" do
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@io)
    Aikotoba.logger.info("to the app's logger")
    assert_equal "[Aikotoba] to the app's logger\n", @io.string
  ensure
    Rails.logger = original
  end

  test "Aikotoba.logger writes nothing, and doesn't fail, without a Rails.logger" do
    original = Rails.logger
    Rails.logger = nil
    assert Aikotoba.logger.warn("nowhere")
    assert_not Aikotoba.logger.warn?
  ensure
    Rails.logger = original
  end

  test "it works through a BroadcastLogger with more than one logger, where tagged doesn't" do
    other = StringIO.new
    broadcast = ActiveSupport::BroadcastLogger.new(ActiveSupport::Logger.new(@io), ActiveSupport::Logger.new(other))
    Aikotoba::PrefixedLogger.new(broadcast).info("once to each")
    assert_equal "[Aikotoba] once to each\n", @io.string
    assert_equal "[Aikotoba] once to each\n", other.string
  end
end
