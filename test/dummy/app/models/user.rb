class User < ApplicationRecord
  has_one :account, class_name: 'Aikotoba::Account'
end
