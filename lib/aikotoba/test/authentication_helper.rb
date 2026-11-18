# frozen_string_literal: true

module Aikotoba
  module Test
    module AuthenticationHelper
      # NOTE: Shared by Request and System: the engine path of a route in the given scope
      #       (scope: :admin uses admin_create_session_path), and the code to enter when the
      #       password step asked for one.
      module Scoped
        private

        def aikotoba_scoped_test_path(route, scope)
          aikotoba_test_scope(scope)
          name = (scope.to_s == "default") ? route : :"#{scope}_#{route}"
          aikotoba.public_send(name)
        end

        # NOTE: The code the password step just issued, only when its response sent the account
        #       on to the scope's code page. A code left over from an earlier sign in that was
        #       never finished is never entered after a wrong password.
        def aikotoba_two_factor_test_code(account, scope, response)
          return unless response.redirect?
          return unless URI(response.location).path == aikotoba_scoped_test_path(:new_two_factor_path, scope)

          account.reload.email_otp_code&.code
        end

        def aikotoba_test_scope(scope)
          Aikotoba.scopes[scope] || raise(ArgumentError, "unknown Aikotoba scope: #{scope.inspect}")
        end
      end

      module Request
        include Scoped

        def aikotoba_sign_out(scope: :default)
          delete aikotoba_scoped_test_path(:destroy_session_path, scope)
          follow_redirect!
        end

        # NOTE: In a scope with two_factor_authenticatable, also enters the code the password
        #       step just issued, so the account ends up signed in either way.
        def aikotoba_sign_in(account, password:, scope: :default)
          post aikotoba_scoped_test_path(:create_session_path, scope), params: {account: {email: account.email, password: password}}
          if (code = aikotoba_two_factor_test_code(account, scope, response))
            post aikotoba_scoped_test_path(:create_two_factor_path, scope), params: {two_factor: {code: code}}
          end
          follow_redirect!
        end
      end

      module System
        include Scoped

        def aikotoba_sign_out(scope: :default)
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection { page.driver.send(:delete, aikotoba_scoped_test_path(:destroy_session_path, scope)) }
          else
            raise NotImplementedError, "Sorry. Only RackTest::Driver is supported as a test helper for Aikotoba's authentication."
          end
        end

        # NOTE: See Request#aikotoba_sign_in.
        def aikotoba_sign_in(account, password:, scope: :default)
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection do
              page.driver.send(:post, aikotoba_scoped_test_path(:create_session_path, scope), account: {email: account.email, password: password})
              if (code = aikotoba_two_factor_test_code(account, scope, page.driver.response))
                page.driver.send(:post, aikotoba_scoped_test_path(:create_two_factor_path, scope), two_factor: {code: code})
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
        ensure
          ActionController::Base.allow_forgery_protection = csrf_protection
        end
      end
    end
  end
end
