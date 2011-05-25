class ProfileController < ApplicationController
  RENREN_PROFILE_PATH = "/var/www/renren/"

  before_filter :authenticate_user!

  def index
    session[:check_profile_time] = DateTime.now
    thu_no = current_user.get_thu_no
    if (thu_no.nil? || current_user.user_extra.nil?)
      logger.debug 'INVALID THU_NO OR USER_EXTRA'
      redirect_to :events
      return
    end
    Dir.chdir(RENREN_PROFILE_PATH)
    filenames = Dir['*'+thu_no.to_s]
    if (filenames.nil? || filenames.size == 0)
      logger.debug 'INVALID FILENAMES'
      redirect_to :events
      return
    end
    filename = filenames[0]

    file = File.open(filename + '/info.txt')
    lines = file.readlines
    @department = lines[2]
    @name = current_user.friendly_name
    #TODO high school in the future

    if (lines.size <= 6)
      logger.debug 'INVALID INFO FILE'
      redirect_to :events
      return
    end

    @num_selection = lines[6].to_i

    if (@num_selection == 0)
      redirect_to :events
      return
    end

    @renren_urls = []
    @photo_urls = []
    for i in 0...@num_selection
      @renren_urls << lines[7 + i*3]
      @photo_urls << lines[8 + i*3]
    end

    @user = current_user
  end

  def select
    user_extra = current_user.user_extra

    if (params[:hide_profile])
      user_extra.hide_profile = true
      user_extra.profile_status = User::PROFILE_CONFIRMED
      user_extra.save!
    end

    if (params[:renren_url] && params[:photo_url] && params[:department])
      user_extra.renren_url = params[:renren_url]
      user_extra.photo_url = params[:photo_url]
      user_extra.department = params[:department]
      user_extra.hide_profile = false
      user_extra.profile_status = User::PROFILE_CONFIRMED
      user_extra.save!
    end

    redirect_to :events
    return
  end

  def show
    @target_user = User.find(params[:target_user])
    authorize! :show, @target_user
    @email = @target_user.email if @target_user.has_valid_email
    @photo_url = @target_user.user_extra.photo_url
    @renren_url = @target_user.user_extra.renren_url
    @unconfirmed = (@renren_url && @photo_url && @target_user.user_extra.profile_status != User::PROFILE_CONFIRMED)
    @department = @target_user.user_extra.department
    @address = @target_user.user_extra.address
    @phone = @target_user.user_extra.phone
    @email ||= '未填写'
    @department ||= '未填写'
    @address ||= '未填写'
    @phone ||= '未填写'
  end

  def validate
    user = User.find(params[:user_id])
    email = params[:email]
    token = params[:token]
    uid = user.user_identifier.find_by_login_type_and_login_value(UserIdentifier::TYPE_EMAIL, email)
    if (uid.nil? || uid.confirm_token != token)
      flash[:alert] = "验证失败"
      return
    end
    uid.confirmed = true
    uid.save!
    flash[:notice] = "验证成功"
    redirect_to "/"
  end
end
