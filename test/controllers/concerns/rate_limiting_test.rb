# frozen_string_literal: true

require "test_helper"

class Aikotoba::Protection::RateLimitingTest < ActiveSupport::TestCase
  def build_controller
    Class.new do
      include Aikotoba::Protection::RateLimiting

      class << self
        attr_reader :applied

        def controller_path
          "aikotoba/confirms"
        end

        def rate_limit(**options)
          (@applied ||= []) << options
        end
      end
    end
  end

  test "empty options apply nothing" do
    controller = build_controller
    controller.aikotoba_rate_limit({})
    assert_nil controller.applied
  end

  test "defaults only: to :create and scope: to the controller's path, and leaves with: to Rails" do
    controller = build_controller
    controller.aikotoba_rate_limit({to: 1, within: 1.minute})
    assert_equal [{to: 1, within: 1.minute, only: :create, scope: "aikotoba/confirms"}], controller.applied
  end

  test "keeps only:, except: and with: set in the options" do
    controller = build_controller
    custom = -> { head :too_many_requests }
    controller.aikotoba_rate_limit({to: 1, within: 1.minute, only: %i[new create], with: custom})
    controller.aikotoba_rate_limit({to: 1, within: 1.minute, except: :destroy, scope: "custom"})
    assert_equal [
      {to: 1, within: 1.minute, only: %i[new create], with: custom, scope: "aikotoba/confirms"},
      {to: 1, within: 1.minute, except: :destroy, scope: "custom"}
    ], controller.applied
  end

  test "does not change the setting it is given" do
    options = {to: 1, within: 1.minute}
    build_controller.aikotoba_rate_limit(options)
    assert_equal({to: 1, within: 1.minute}, options)
  end
end
