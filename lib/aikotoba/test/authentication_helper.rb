# frozen_string_literal: true

module Aikotoba
  module Test
    module AuthenticationHelper
      module Request
        def aikotoba_sign_out
          delete aikotoba.destroy_session_path
          follow_redirect!
        end

        # NOTE: With two_factor_authenticatable on the default scope, also enters the code
        #       the password step just issued, so the account ends up signed in either way.
        def aikotoba_sign_in(account, password:)
          post aikotoba.new_session_path, params: {account: {email: account.email, password: password}}
          if Aikotoba.default_scope.two_factor_authenticatable? && (code = account.reload.email_otp_code)
            post aikotoba.create_two_factor_path, params: {two_factor: {response: code.code}}
          end
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

        def aikotoba_sign_in(account, password:)
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection do
              page.driver.send(:post, aikotoba.new_session_path, account: {email: account.email, password: password})
              # NOTE: See Request#aikotoba_sign_in.
              if Aikotoba.default_scope.two_factor_authenticatable? && (code = account.reload.email_otp_code)
                page.driver.send(:post, aikotoba.create_two_factor_path, two_factor: {response: code.code})
              end
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
