class User < ApplicationRecord
  include Aikotoba::ModelHelper

  validates :secret_digest, presence: true
end
