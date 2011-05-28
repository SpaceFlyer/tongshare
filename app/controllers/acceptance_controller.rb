class AcceptanceController < ApplicationController
  include RegistrationsExtendedHelper
  before_filter :authenticate_user!

  def right_email?
    email = params[:email]
    return true if email.nil?
    return current_user.email == email
  end
  
  def create
    authorize! :create, Acceptance
  end

  def destroy
    authorize! :destroy, Acceptance
  end

  def accept
    if (params[:id])
      begin
        sharing = Sharing.find(params[:id], :include => [:event])
        event = sharing.event
      rescue ActiveRecord::RecordNotFound
        redirect_to :events, :alert => I18n.t('tongshare.sharing.sharing_not_found')
        return
      end
    else
      event = Event.find(params[:event])
      token = params[:share_token]
      unless (event.public? || token && event.share_token == token)
        redirect_to :events, alert => I18n.t('tongshare.sharing.sharing_not_found')
      end
      right_token = true
    end

    if (!right_email? && current_user.has_valid_email)
      flash[:alert] = I18n.t 'tongshare.sharing.wrong_email'
      if can? :read, event
        redirect_to event
      else
        redirect_to :events
      end
      return
    end

    try_set_email(params[:email])

    acc = Acceptance.find_or_create_by_user_id_and_event_id(:user_id => current_user.id, :event_id => event.id)
    authorize! :accept, acc unless (right_token && current_user.id != event.creator_id)
    acc.decision = true
    acc.save!

    if (sharing)
      mail = SysMailer.accept_or_deny_sharing_email(sharing, acc)
      mail.deliver if !mail.nil?
    end
    flash[:notice] = I18n.t 'tongshare.acceptance.accepted', :name => event.name
    redirect_to event

    News.create!(:user_id => current_user.id, :action => News::ACTION_JOIN, :target_event_id => acc.event_id)
  end

  def deny
    if (params[:id])
      begin
        sharing = Sharing.find(params[:id], :include => [:event])
        event = sharing.event
      rescue ActiveRecord::RecordNotFound
        redirect_to :events, :alert => I18n.t('tongshare.sharing.sharing_not_found')
        return
      end
    else
      event = Event.find(params[:event])
      token = params[:share_token]
      unless (event.public? || token && event.share_token == token)
        redirect_to :events, alert => I18n.t('tongshare.sharing.sharing_not_found')
      end
      right_token = true
    end

    if (!right_email? && current_user.has_valid_email)
      flash[:alert] = I18n.t 'tongshare.sharing.wrong_email'
      if can? :read, event
        redirect_to event
      else
        redirect_to :events
      end
      return
    end

    try_set_email(params[:email])
    
    acc = Acceptance.find_or_create_by_user_id_and_event_id(:user_id => current_user.id, :event_id => event.id)
    authorize! :deny, acc unless (right_token && current_user.id != event.creator_id)
    acc.decision = false
    acc.save!

    if (sharing)
      mail = SysMailer.accept_or_deny_sharing_email(sharing, acc)
      mail.deliver if !mail.nil?
    end
    flash[:notice] = I18n.t 'tongshare.acceptance.denied', :name => event.name
    if can? :read, event
      redirect_to event
    else
        redirect_to :events
    end
  end

  def exit
    acc = Acceptance.find(params[:id])
    authorize! :exit, acc
    acc.decision = false
    acc.save!

    News.create!(:user_id => current_user.id, :action => News::ACTION_QUIT, :target_event_id => acc.event_id)

#    mail = SysMailer.accept_or_deny_sharing_email(acc)
#    mail.deliver if !mail.nil?
    flash[:notice] = I18n.t 'tongshare.acceptance.exited', :name => acc.event.name
    if can? :read, acc.event
      redirect_to acc.event
    else
        redirect_to :events
    end
  end
end
