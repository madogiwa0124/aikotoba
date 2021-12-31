module Aikotoba
  module Lockable
    extend ActiveSupport::Concern

    def reset_lock_status!(account)
      account.unlock! if account.failed_attempts.positive?
    end

    def lock_if_exceed_max_failed_attempts!(email:)
      account = Aikotoba::Account.find_by(email: email)
      if account
        account.lock_when_exceed_max_failed_attempts!
        account.send_unlock_token if account.locked?
      end
    end
  end
end
