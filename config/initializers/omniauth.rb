module OmniAuth
  module Strategies
<<<<<<< HEAD
    autoload :DCAuth, Rails.root.join('lib', 'strategies', 'dc_auth') 
=======
    autoload :DCAuth, Rails.root.join('lib', 'strategies', 'dc_auth')
>>>>>>> 9edda164b2ab478ca5799fc97ea5d0f3db7e610a
  end
end


secrets = DC::SECRETS['omniauth']

if secrets.blank?
  STDERR.puts "OmniAuth secrets are not available.  Not performing initialization"
else

  # For Google: Remember to customize the redirect URI for the key to be: /auth/google_oauth2/callback
  # If you do happen to forget and do so later, REDOWNLOAD the key, it changes every time you edit the settings.

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :twitter  , secrets['twitter']['key'], secrets['twitter']['secret']
    provider :facebook , secrets['facebook']['key'], secrets['facebook']['secret'], { :scope => 'email' }
    provider :google_oauth2, secrets['google']['key'], secrets['google']['secret'], { :access_type=>'online',:approval_prompt=>''}
<<<<<<< HEAD

    provider :dc_auth,  secrets['documentcloud']['key'],  secrets['documentcloud']['secret'], 
                        client_options: { site: secrets['documentcloud']['site'],
                                          authorize_url: secrets['documentcloud']['authorize_url'] }
=======
    provider :dc_auth,  secrets['documentcloud']['key'],  secrets['documentcloud']['secret'],
                        client_options: { site: secrets['documentcloud']['site'],
                                          authorize_url: secrets['documentcloud']['authorize_url'] }

>>>>>>> 9edda164b2ab478ca5799fc97ea5d0f3db7e610a
  end

  OmniAuth.config.add_camelization 'oauth', 'OAuth'
  OmniAuth.config.add_camelization 'omniauth', 'OmniAuth'
  OmniAuth.config.add_camelization 'dc_auth', 'DCAuth'
  # If a third party auth session is started but then the person selects cancel instead of completing
  # the session, then the below block gets called.
  OmniAuth.config.on_failure = Proc.new do |env|
    error = env['omniauth.error.type']
    origin = (env['omniauth.origin'] &&CGI.unescape( env['omniauth.origin'] ) ) || ''
    new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{error}&origin=#{origin}"
    Rack::Response.new(["302 Moved"], 302, 'Location' => new_path).finish
  end

end
