class RegistrationsExtendedController < Devise::RegistrationsController
  # POST /resource/sign_up
  def create
    build_resource

    if resource.save
      resource.build_user_extra if resource.user_extra.nil?
      resource.save!
      set_flash_message :notice, :signed_up
      sign_in_and_redirect(resource_name, resource)
    else
      clean_up_passwords(resource)
      render_with_scope :new
    end
  end

  def edit
    resource.build_user_extra if current_user.user_extra.nil?
    authorize! :edit, resource

    if current_user
      if current_user.user_extra
        @photo_url = current_user.user_extra.photo_url
      end
    end
    super
  end

  def update
    s = super
    return s if (s.class != String)
    if (params[:user][:user_extra_attributes][:avatar])
      resource.user_extra.photo_url = resource.user_extra.avatar.url(:thumb)
      resource.user_extra.save!
    end
    if (params[:id_email] && !params[:id_email].blank?)
      old_uid = UserIdentifier.find_by_login_type_and_login_value(UserIdentifier::TYPE_EMAIL, params[:id_email])
      if (old_uid && old_uid.confirmed)
        flash[:alert] = "#{params[:id_email]}已被暂用"
        return
      end
      uid = old_uid ? old_uid : resource.user_identifier.build(:login_type => UserIdentifier::TYPE_EMAIL,
                                                               :login_value => params[:id_email],
                                                               :confirm_token => rand(36**8).to_s(36))
      uid.user_id = resource.id
      uid.save!
      mail = SysMailer.validate_mail(resource.id, uid)
      mail.deliver if !mail.nil?
    end
    News.create!(:user_id => resource.id, :action => News::ACTION_PROFILE)
  end
end
