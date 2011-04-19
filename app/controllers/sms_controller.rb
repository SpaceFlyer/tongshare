class SmsController < ApplicationController
  def edit
    mobile = params[:mobile]
    return if (mobile.nil? || mobile.blank?)
    mobile = mobile.strip
    if (!mobile.match UserExtra::MOBILE_REGEX)
      flash[:alert] = '您输入的手机号格式有误，正确的格式如13012345678'
      return
    end
    mobile_id = UserIdentifier.find_by(UserIdentifier::TYPE_MOBILE, mobile)
    if (mobile_id.nil? || current_user.sms_confirmation.nil? || !current_user.sms_confirmation.confirmed)
      current_user.user_extra.mobile = mobile
      current_user.user_extra.save!
      sms_confirmation = SmsConfirmation.find_by_user_id(current_user.id)
      if (sms_confirmation.nil?)
        SmsConfirmation.create!(:user_id => current_user.id)
        sms_confirmation = SmsConfirmation.find_by_user_id(current_user.id)
      end
      sms_confirmation.token = rand(10**4).to_s(10)
      sms_confirmation.confirmed = false
      sms_confirmation.save!
      #TODO next send SMS
      flash[:notice] = '为验证您的手机号码，4位数字的验证码已经发送到您的手机，请输入验证码完成手机绑定'
      redirect_to "/sms/confirm"
    else
      flash[:notice] = '手机号已绑定'
      redirect_to "/events/"
    end
  end

  def confirm
    token = params[:confirm]
    return if (token.nil? || token.blank?)
    sms_confirmation = current_user.sms_confirmation
    if (token == sms_confirmation.token)
      mobile_id = UserIdentifier.find_by_user_id_and_login_type(current_user.id, UserIdentifier::TYPE_MOBILE)
      mobile_id.destroy unless mobile_id.nil?
      UserIdentifier.create!(:user_id => current_user.id,
        :login_type => UserIdentifier::TYPE_MOBILE,
        :login_value => current_user.user_extra.mobile,
        :confirmed => true)
      sms_confirmation.confirmed = true
      flash[:notice] = '手机号已绑定'
      redirect_to '/events/'
    else
      flash[:alert] = '验证码错误'
    end
  end

end
