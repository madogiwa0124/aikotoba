require 'aikotoba'

Aikotoba.authenticate_class = 'User'
Aikotoba.session_key = 'aikotoba-user-id'
Aikotoba.secret_generator = -> { SecureRandom.hex(16) }
Aikotoba.secret_papper = 'aikotoba-default-papper'
Aikotoba.secret_stretch = 3
Aikotoba.secret_digest_generator = ->(secret) { Digest::SHA256.hexdigest(secret) }
Aikotoba.sign_in_path = '/sign_in'
Aikotoba.sign_up_path = '/sign_up'
Aikotoba.sign_out_path = '/logout'
Aikotoba.after_sign_in_path = '/sensitives'
Aikotoba.failed_sign_in_path= '/sign_in'
Aikotoba.after_sign_up_path = '/sign_in'
Aikotoba.after_sign_out_path = '/sign_in'
