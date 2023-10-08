class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  if Rails.env.development?
    # NOTE: use multiple databases
    connects_to database: { writing: :primary, reading: :replica }
  end
end
