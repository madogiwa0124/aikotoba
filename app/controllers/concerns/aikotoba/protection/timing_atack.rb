# frozen_string_literal: true

# NOTE: Add random delay for Timing attack.
# https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/10-Business_Logic_Testing/04-Test_for_Process_Timing
module Aikotoba
  module Protection::TimingAtack
    extend ActiveSupport::Concern

    def prevent_timing_atack
      random_delay if aikotoba_prevent_timing_atack
    end

    private

    def aikotoba_prevent_timing_atack
      Aikotoba.prevent_timing_atack
    end

    def random_delay
      sleep (1..5).to_a.sample / 100.0
    end
  end
end
