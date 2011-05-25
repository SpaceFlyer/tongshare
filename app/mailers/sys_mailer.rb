class SysMailer < ActionMailer::Base
  helper :application
  
  include RegistrationsExtendedHelper
  include EventsHelper  #add by Wander
  
  default :from => "同享日程 <no-reply@tongshare.com>"  #modified by Wander
  default_url_options[:host] = SITE

  layout 'sys_mailer' #add by Wander

  def test_email(to)
    mail(:to => to, :subject => "Test for sending email")
  end
  
  def warning_email(user, instance)
    @user = user
    @instance = instance
    if (!nil_email_alias?(user.email) && user.confirmed? && user.user_extra && !user.user_extra.reject_warning_flag)
      str = (@instance.warning_count > 0 ? "有" : "解除")
      headers = {:to => @user.email,
        :subject => str + I18n.t("tongshare.warning") + ":" + instance.name}
      return mail(headers)
    else
      return nil
    end
  end

  def reminder_email(user)
    @user = user
    mail(:to => user.email, 
         :subject => "Reminder:"
        )
  end
  
  def user_sharing_request_email(user_sharing)
    @user = User.find(user_sharing.user_id)
    @shared_from = User.find(user_sharing.sharing.shared_from)
    @user_sharing = user_sharing
    @event = user_sharing.sharing.event #add by Wander
    @friendly_time_range = friendly_time_range(@event.begin, @event.end)  #add by Wander
    @friendly_rrule = show_friendly_rrule(@event) #added by SpaceFlyer

    if !nil_email_alias?(@user.email)
      headers = {:to => @user.email,
                 :subject => I18n.t("tongshare.sharing.email.subject", :user_name => @shared_from.friendly_name)}
      headers[:reply_to] = @shared_from.email if !nil_email_alias?(@shared_from.email)
      mail(headers)
    else
      nil
    end
  end

  def user_sharing_request_new_email(sharing, new_email)
    @email = new_email
    @sharing = sharing
    @shared_from = User.find(sharing.shared_from)
    @event = sharing.event #add by Wander
    @friendly_time_range = friendly_time_range(@event.begin, @event.end)  #add by Wander
    @friendly_rrule = show_friendly_rrule(@event) #added by SpaceFlyer

    headers = {:to => new_email,
               :subject => I18n.t("tongshare.sharing.email.subject", :user_name => @shared_from.friendly_name)}
    headers[:reply_to] = @shared_from.email if !nil_email_alias?(@shared_from.email)
    mail(headers)
  end

  def accept_or_deny_sharing_email(sharing, acceptance)
    @acceptance = acceptance
    @sharing = sharing
    @shared_from = User.find(sharing.shared_from) #modified by Wander
    @shared_to = acceptance.user
    @event = sharing.event
    @friendly_time_range = friendly_time_range(@event.begin, @event.end)
    @friendly_rrule = show_friendly_rrule(@event)

    if !nil_email_alias?(@shared_from.email)
      headers = {:to => @shared_from.email}
      if acceptance.decision == Acceptance::DECISION_ACCEPTED
        headers[:subject] = I18n.t("tongshare.acceptance.email.accepted_subject", :name => @shared_to.friendly_name)
      elsif acceptance.decision == Acceptance::DECISION_DENY
        headers[:subject] = I18n.t("tongshare.acceptance.email.denied_subject", :name => @shared_to.friendly_name)
      else
        return nil
      end
      mail(headers)
    end
  end

  def validate_mail(user_id, email_id)
    return nil if email_id.login_type != UserIdentifier::TYPE_EMAIL
    @email = email_id.login_value
    @user_id = user_id
    @token = email_id.confirm_token
    @auth_token = User.find(user_id).authentication_token
    headers = {:to => @email, :subject => "身份验证邮箱确认"}
    mail(headers)
  end

end
