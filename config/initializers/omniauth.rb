require 'omniauth/strategies/upwork'
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = Proc.new do |env|
  Auth::CallbacksController.action(:oauth_failure).call(env)
end

OmniAuth.config.full_host = ENV["BASE_URL"]
OmniAuth.config.allowed_request_methods = %i[get post]
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :upwork,
           ENV.fetch('UPWORK_CLIENT_ID', ''),
           ENV.fetch('UPWORK_CLIENT_SECRET', '')
end
