# frozen_string_literal: true

module Aikotoba
  class Account::Value::Password
    LENGTH_RENGE = Aikotoba.password_length_range

    def initialize(
      value:,
      pepper: Aikotoba.password_pepper,
      algorithm_class: Argon2
    )
      @value = value
      @pepper = pepper
      @algorithm = algorithm_class.new(password: password_with_pepper(@value))
    end

    attr_reader :value

    def match?(digest:)
      @algorithm.verify_password?(digest)
    end

    def digest
      return "" if value.blank?
      @algorithm.generate_hash
    end

    private

    def password_with_pepper(password)
      "#{password}-#{@pepper}"
    end
  end
end
