# frozen_string_literal: true

module Aikotoba
  # NOTE: A QR code as an inline <svg> element, done by the rqrcode gem. TotpCredential uses it
  #       by default for provisioning_qr_code_svg and takes another class answering the same
  #       methods as qr_code_class: (a different look, or a PNG). Kept apart from
  #       TotpCredential::Algorithm: it's another gem, and the part an app is likelier to replace.
  #       Required only here, as TotpCredential::Algorithm does with rotp.
  class Account::TwoFactor::TotpCredential::QrCode
    def initialize(data:)
      require "rqrcode"
      @data = data
    end

    # NOTE: Fixed options: the size is the page's to set, since viewbox: true leaves out width
    #       and height so the <svg> fills its container (module_size only sets the viewBox
    #       units). offset is the 4-module quiet zone a QR code needs around it, and fill paints
    #       it and the background white, so the code still scans on a dark page.
    #       rqrcode's XML declaration is removed, since it has no place inside HTML.
    QUIET_ZONE_MODULES = 4
    MODULE_SIZE = 4

    def svg
      RQRCode::QRCode.new(@data)
        .as_svg(module_size: MODULE_SIZE, offset: QUIET_ZONE_MODULES * MODULE_SIZE, fill: "fff",
          use_path: true, viewbox: true, standalone: true)
        .sub(/\A<\?xml[^>]*\?>/, "")
    end
  end
end
