# frozen_string_literal: true

module ApiCommitteeHelper
  SPEC_PATH = File.expand_path("../../app/controllers/aikotoba/api/spec.yml", __dir__)

  module Options
    def committee_options
      @committee_options ||= {
        schema_path: ApiCommitteeHelper::SPEC_PATH,
        parse_response_by_content_type: false,
        strict_reference_validation: true
      }
    end
  end

  def self.included(base)
    base.include Committee::Rails::Test::Methods
    base.include Options
  end
end
