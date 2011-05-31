class ApplicationController < ActionController::Base
  # mobile helper
  has_mobile_fu
  
  protect_from_forgery

  before_filter :export_i18n_messages
  before_filter :manual_notice
  before_filter :check_user

  private
  def export_i18n_messages
    SimplesIdeias::I18n.export! if Rails.env.development?
    #export i18n for js
  end

  def manual_notice
    if (params[:notice])
      flash[:notice] = params[:notice]
      # Anything after notice parameter is skipped!
      # So be bareful that no important parameter should ever be after notice
      redirect_to request.request_uri.sub(/[\?&]?notice=.*/, '')
    end
  end

  def check_user
    if (current_user && current_user.user_extra.name.blank? && !(request.fullpath.include? '/users'))
      flash[:alert] = "欢迎来到“i.同享”，请首先填写您的个人资料，其中姓名为必填。您的资料越完善就越有可能获得Ta的青睐^_^"
      redirect_to '/users/edit'
    end
  end

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end
end

