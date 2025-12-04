class Admin < ApplicationRecord
  has_one :account, class_name: "Aikotoba::Account", as: :authenticate_target
end
