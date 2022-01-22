# frozen_string_literal: true

module Aikotoba
  module Test
    module AuthenticationHelper
      module Request
        def aikotoba_sign_out
          delete aikotoba.destroy_session_path
          follow_redirect!
        end

        def aikotoba_sign_in(account)
          post aikotoba.new_session_path, params: {account: {email: account.email, password: account.password}}
          follow_redirect!
        end
      end

      module System
        def aikotoba_sign_out
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection { page.driver.send(:delete, aikotoba.destroy_session_path) }
          else
            raise NotImplementedError, "Sorry. Only RackTest::Driver is supported as a test helper for Aikotoba's authentication."
          end
        end

        def aikotoba_sign_in(account)
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection do
              page.driver.send(:post, aikotoba.new_session_path, account: {email: account.email, password: account.password})
            end
          else
            raise NotImplementedError, "Sorry. Only RackTest::Driver is supported as a test helper for Aikotoba's authentication."
          end
        end

        private

        def disable_forgery_protection
          csrf_protection = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = false
          yield
          ActionController::Base.allow_forgery_protection = csrf_protection
        end
      end
    end
  end
end
