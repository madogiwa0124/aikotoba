module Aikotoba
  module Lockable
    extend ActiveSupport::Concern

    def reset_lock_status_if_lockable!(account)
      return unless enable_lock?
      account.unlock! if account.failed_attempts.positive?
    end

    def lock_if_lockable_and_exceed_max_failed_attempts!(strategy, email)
      return unless enable_lock?
      account = Aikotoba::Account.where(strategy: strategy).find_by(email: email)
      if account
        account.lock_when_exceed_max_failed_attempts!
        account.send_unlock_token if account.locked?
      end
    end

    private

    def enable_lock?
      ::Aikotoba::Account.enable_lock?
    end
  end
end
