# frozen_string_literal: true

module Aikotoba
  module Test
    module AuthenticationHelper
      module Request
        def aikotoba_sign_out
          delete Aikotoba.sign_out_path
          follow_redirect!
        end

        def aikotoba_sign_in(account)
          use_password_only_strategy do
            post Aikotoba.sign_in_path, params: {account: {password: account.password, strategy: :password_only}}
          end
          follow_redirect!
        end

        private

        def use_password_only_strategy
          old_strategy = Aikotoba.authentication_strategy
          Aikotoba.authentication_strategy = :password_only
          yield
          Aikotoba.authentication_strategy = old_strategy
        end
      end

      module System
        def aikotoba_sign_out
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection { page.driver.send(:delete, Aikotoba.sign_out_path) }
          else
            raise NotImplementedError, "Sorry. Only RackTest::Driver is supported as a test helper for Aikotoba's authentication."
          end
        end

        def aikotoba_sign_in(account)
          if page.driver.is_a?(Capybara::RackTest::Driver)
            disable_forgery_protection do
              use_password_only_strategy do
                page.driver.send(:post, Aikotoba.sign_in_path, account: {password: account.password, strategy: :password_only})
              end
            end
          else
            raise NotImplementedError, "Sorry. Only RackTest::Driver is supported as a test helper for Aikotoba's authentication."
          end
        end

        private

        def use_password_only_strategy
          old_strategy = Aikotoba.authentication_strategy
          Aikotoba.authentication_strategy = :password_only
          yield
          Aikotoba.authentication_strategy = old_strategy
        end

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
