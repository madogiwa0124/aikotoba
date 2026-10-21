module Aikotoba
  module Errors
    class Base < StandardError; end

    class NotAvailableException < Base; end

    class InvalidScopeConfiguration < Base; end

    class PlaintextTokenUnavailable < Base; end
  end
end
