# frozen_string_literal: true

module Aikotoba
  module Test
    module AuthenticationHelper
      # NOTE: Shared by Request and System: the engine path of a route in the given scope
      #       (scope: :admin uses admin_create_session_path), and the code to enter when the
      #       password step asked for one.
      module Scoped
        # NOTE: How a test gets a valid code for each strategy, kept here rather than as
        #       test-only methods on the strategies. A strategy added to
        #       Account::TwoFactor::STRATEGIES adds its entry here too.
        #       TOTP: the code for now, or for the step after the last one accepted when that was
        #       now (within the one step of drift allowed), so an account can sign in twice in a
        #       test without waiting 30 seconds. When that step is beyond the drift allowed (a third
        #       sign in in the same step, or a code from the next step accepted last), no code is
        #       valid yet, so it raises asking for `travel` rather than entering one that fails.
        TWO_FACTOR_TEST_CODES = {
          "email_otp" => ->(account) { account.email_otp_code&.code },
          "totp" => lambda do |account|
            credential = account.totp_credential
            next unless credential

            at = [Time.current, Time.at(credential.last_otp_at.to_i + 30)].max
            if at > Time.current + Aikotoba::Account::TwoFactor::TotpCredential::DRIFT
              raise "No TOTP code for #{account.email} is valid until #{at}: its codes up to then were used. " \
                "travel 30.seconds before signing in again."
            end
            Aikotoba::Account::TwoFactor::TotpCredential::Algorithm.new(secret: credential.secret, issuer: nil).generate_code(at: at)
          end
        }.freeze

        private

        def aikotoba_scoped_test_path(route, scope)
          aikotoba_test_scope(scope)
          name = (scope.to_s == "default") ? route : :"#{scope}_#{route}"
          aikotoba.public_send(name)
        end

        # NOTE: The code for the strategy the account was challenged with, only when the password
        #       step's response sent it on to the scope's code page. A code left over from an
        #       earlier sign in that was never finished is never entered after a wrong password.
        def aikotoba_two_factor_test_code(account, scope, response)
          return unless response.redirect?
          return unless URI(response.location).path == aikotoba_scoped_test_path(:new_two_factor_path, scope)

          account.reload
          strategy = account.two_factor.strategy_for(aikotoba_test_scope(scope).two_factor_strategies)
          TWO_FACTOR_TEST_CODES.fetch(strategy).call(account)
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

        # NOTE: In a scope with two_factor_strategies, also enters the code the password
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
