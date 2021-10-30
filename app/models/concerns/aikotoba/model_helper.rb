module Aikotoba
  module ModelHelper
    extend ActiveSupport::Concern

    included do
      private_class_method :default_secret_salt
    end

    module ClassMethods
      # NOTE: 　By default, salt is fixed for simplicity of use in development environments. 
      # If you need more security, consider overriding it with a different value for each record.
      def build_with_secret(attributes = nil, secret_salt: default_secret_salt)
        new(attributes).tap do |resource|
          secret_digest = build_digest(secret: resource.secret, salt: default_secret_salt)
          resource.assign_attributes(secret_digest: secret_digest)
        end
      end

      def find_by_secret(secret, secret_salt: default_secret_salt)
        find_by(secret_digest: build_digest(secret: secret, salt: secret_salt))
      end

      def build_digest(secret:, salt:)
        stretch, papper = Aikotoba.secret_stretch, Aikotoba.secret_papper
        hash_generator = Aikotoba.secret_digest_generator
        (1..stretch).inject("#{secret}-#{salt}-#{papper}") { |result, _| hash_generator.call(result) }
      end

      # NOTE: 　The default salt is a predictable value. 
      # If you need more security, consider overriding it and setting an unpredictable safe value.
      def default_secret_salt
        'aikotoba-default-salt'
      end 
    end

    def secret
      @secret ||= Aikotoba.secret_generator.call
    end
  end
end
