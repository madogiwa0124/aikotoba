# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    belongs_to :authenticate_target, polymorphic: true, optional: true
    validates :password_digest, presence: true

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
      end
    end

    class << self
      def build_with_password(attributes = nil, password_salt: default_password_salt)
        new(attributes).tap do |resource|
          password_digest = build_digest(password: resource.password, salt: password_salt)
          resource.assign_attributes(password_digest: password_digest)
        end
      end

      # NOTE: 　By default, salt is fixed for simplicity of use in development environments.
      # If you need more security, consider overriding it with a different value for each record.
      def find_by_password(password, password_salt: default_password_salt)
        find_by(password_digest: build_digest(password: password, salt: password_salt))
      end

      def build_digest(password:, salt:)
        stretch, papper = Aikotoba.password_stretch, Aikotoba.password_papper
        hash_generator = Aikotoba.password_digest_generator
        (1..stretch).inject("#{password}-#{salt}-#{papper}") { |result, _| hash_generator.call(result) }
      end

      # NOTE: 　The default salt is a predictable value.
      # If you need more security, consider overriding it and setting an unpredictable safe value.
      def default_password_salt
        "aikotoba-default-salt"
      end
    end

    def password
      @password ||= Aikotoba.password_generator.call
    end
  end
end
