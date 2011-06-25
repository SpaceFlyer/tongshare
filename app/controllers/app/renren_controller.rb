class App::RenrenController < ApplicationController
  include App::RenrenHelper
  
  def signin
    redirect_to client.web_server.authorize_url(:redirect_uri => RENREN_REDIRECT_URI)
  end

  def callback
    access_token = client.web_server.get_access_token(params[:code], :redirect_uri => RENREN_REDIRECT_URI)
    resp = api_call(access_token, 'users.getInfo')
    info = MultiJson.decode(resp) rescue nil
    id = "#{RENREN_FIX}." + info[0]['uid'].to_s
    old_id = UserIdentifier.find_by_login_type_and_login_value(UserIdentifier::TYPE_EMPLOYEE_NO, id)
    if (old_id.nil?)
      # create a new user
      user = User.new(
        :email => "#{UUIDTools::UUID.random_create}@null.#{RENREN_FIX}",
        :password => random_password
      )
      user.save!
      user.user_identifier.build(:login_value => id, :login_type => UserIdentifier::TYPE_EMPLOYEE_NO)
      user.user_extra = UserExtra.create(:name => info[0]['name'])
      user.save!
    else
      user = old_id.user
    end
    sign_in user
    redirect_to root_url
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
  
  #TODO: merge with registrations_extended_helper
  def random_password(size = 8)
    chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
    (1..size).collect{|a| chars[rand(chars.size)] }.join
  end

  
end
