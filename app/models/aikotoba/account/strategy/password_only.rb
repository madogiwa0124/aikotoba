# frozen_string_literal: true

module Aikotoba
  class Account::Strategy::PasswordOnly
    def self.build_account_by(attributes)
      new.build_account_by(password: attributes["password"])
    end

    def self.find_account_by(credentials)
      new.find_account_by(password: credentials["password"])
    end

    def build_account_by(password: nil)
      build_with_password(password)
    end

    def find_account_by(password:)
      find_by_password(password)
    end

    private

    def build_with_password(password = nil, password_salt: default_password_salt)
      Aikotoba::Account.new(password: password).tap do |resource|
        resource.password ||= generate_password
        password_digest = build_digest(password: resource.password, salt: password_salt)
        resource.assign_attributes(password_digest: password_digest)
      end
    end

    def generate_password
      SecureRandom.hex(16)
    end

    # NOTE: 　By default, salt is fixed for simplicity of use in development environments.
    # If you need more security, consider overriding it with a different value for each record.
    def find_by_password(password, password_salt: default_password_salt)
      Aikotoba::Account.find_by(password_digest: build_digest(password: password, salt: password_salt))
    end

    def build_digest(password:, salt:)
      stretch, papper = Aikotoba.password_stretch, Aikotoba.password_papper
      (1..stretch).inject("#{password}-#{salt}-#{papper}") { |result, _| generate_hash(result) }
    end

    def generate_hash(password)
      Digest::SHA256.hexdigest(password)
    end

    # NOTE: 　The default salt is a predictable value.
    # If you need more security, consider overriding it and setting an unpredictable safe value.
    def default_password_salt
      "aikotoba-default-salt"
    end
  end
end
