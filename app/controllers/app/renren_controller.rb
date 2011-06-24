require 'oauth2'
require 'digest/md5'
class App::RenrenController < ApplicationController
  include App::RenrenHelper
  def signin
    redirect_to client.web_server.authorize_url(:redirect_uri => RENREN_REDIRECT_URI)
  end

  def callback
    access_token = client.web_server.get_access_token(params[:code], :redirect_uri => RENREN_REDIRECT_URI)
    json = api_call(access_token, 'users.getInfo')
    render :json => json
  end
  
  protected
  
  def client
    @client ||= OAuth2::Client.new(
      RENREN_APP_ID, RENREN_APP_SECRET,
      :site => RENREN_SITE,
      :ssl => {:ca_path => SSL_CA_PATH }, 
      :access_token_url => RENREN_ACCESS_TOKEN_URL
    )
  end
end
