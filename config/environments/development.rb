Tongshare::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  #action_mailer settings
  config.action_mailer.default_url_options = {
    :host => "127.0.0.1:3000"
  }
  config.action_mailer.delivery_method = :sendmail
#  config.action_mailer.smtp_settings = {
#    :address => 'smtp.gmail.com',
#    :port => 587,
#    :domain => 'tongshare.com',
#    :user_name => 'rubycaltest',
#    :password => 'testcalruby',
#    :authentication => :login,
#    :enable_starttls_auto => true
#  }
  config.action_mailer.sendmail_settings = {
    #default args
    #:arguments => '-i -t' 
  }
  config.action_mailer.default_url_options = { :host => "127.0.0.1:3000" }

  #time zone
  config.time_zone = 'Beijing'

  AUTH_SERVER_PATH = "http://localhost:3001/thuauth/auth_with_xls_and_get_name/"
  SECRET = "this is a secret"

  SITE = "localhost:3000"
  THU_SPECIAL_SECRET = "I am special" # for special user registration (e.g. Association, Centenary)
  
  RENREN_APP_ID = "87fa4d13e57f4f99bec93b8711c8d1f5"
  RENREN_APP_SECRET = "120026030b96459e9aecaf81975d58f9"
  SSL_CA_PATH = "/etc/ssl/certs"
  RENREN_REDIRECT_URI = 'http://' + SITE + "/app/renren/callback"
end

