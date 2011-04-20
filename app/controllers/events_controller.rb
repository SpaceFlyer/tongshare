class EventsController < ApplicationController
  include EventsHelper
  include UsersHelper
  include AuthHelper
  include CurriculumHelper
  include SiteConnectHelper
  include SharingsHelper
  include RegistrationsExtendedHelper

  before_filter :authenticate_user!

  # GET /events
  # GET /events.xml
  def index
    #Recommend 百年校庆活动 manually, this should be replaced automatically later
    #FIXME
    ue = UserExtra.find_by_name('百年校庆')
    @rec_instances = query_next_accepted_instance_includes_event(Time.now, 3, ue.user_id, 0) if ue

    user_extra = current_user.user_extra
    if (user_extra && !user_extra.hide_profile && user_extra.profile_status != User::PROFILE_CONFIRMED)
      last_check_time = session[:check_profile_time]
      if (last_check_time.nil? || last_check_time + 1.day < DateTime.now)
        redirect_to '/profile/index'
        return
      end
    end

    if user_extra
      @photo_url = user_extra.photo_url
    end
    @note = NOTES[rand(NOTES.size)]

    #@events = Event.find_all_by_creator_id current_user.id
    authorize! :index, Event

    params[:range] = "next" unless ["next", "day", "week"].include?(params[:range])
    params[:offset] ||= 0
    params[:limit] ||= 10
    @range = params[:range].to_sym
    @offset = params[:offset].to_i
    @limit = params[:limit].to_i

    if @range == :next
      @instances = query_next_accepted_instance_includes_event(Time.now, @limit + 1, current_user.id, @offset)
      if @instances.count == @limit + 1
        #not the last page
        @instances.delete_at(@instances.count - 1)
        @is_last_page = false
      else
        @is_last_page = true
      end
      @limit = @instances.count
    else
      case @range
        when :day
          from = Date.today + @offset.days
          to = Date.today + @offset.days + 1.days
        when :week
          from = Date.today.beginning_of_week + @offset.weeks
          to = Date.today.beginning_of_week + @offset.weeks + 1.weeks
      end

      #TODO: this month, all(events)

      #logger.debug from.to_time.to_s
      #logger.debug to.to_time.to_s

      @instances = query_all_accepted_instance_includes_event(from.to_time, to.to_time)
    end

    #check confirmation for employee_no
    user_id_rec = current_user.user_identifier.find(:first,
      :conditions => ["login_type = ?", UserIdentifier::TYPE_EMPLOYEE_NO])

    if !user_id_rec.nil?
      @not_confirmed = !user_id_rec.confirmed
      username = user_id_rec.login_value
      username = username.delete(company_domain(current_user) + ".")
      @auth_path = auth_path(username, root_url)
    end

    #sharing
    @invited_user_sharings = query_sharing_event

    @curriculum_empty = curriculum_empty?(current_user)

    @num_friendship_from = current_user.friendship_from.count
    @num_friendship_bidirectional = current_user.friendship_from.where('property=?', Friendship::BIDIRECTIONAL).count

    respond_to do |format|
      format.html # index.html.erb
      #format.xml  { render :xml => @instances }
    end
  end

  # GET /events/1
  # GET /events/1.xml
  def show
    @event = Event.find(params[:id])
    @token = params[:share_token]
    authorize! :show, @event unless (@event.public? || @token && @event.share_token == @token)

    @instance = params[:inst].blank? ? nil : Instance.find(params[:inst])
    @acceptance = find_acceptance(@event)
    @sharings = @event.sharings.all(:conditions => ['user_sharings.user_id = ?', current_user.id], :joins => [:user_sharings])
    @invited_feedbacks = find_invited_feedback(@event.id, current_user.id)

    if (@instance)
      @warninged = (Feedback.where("user_id=? AND instance_id=? AND value=?",
        current_user.id, @instance.id, Feedback::WARNING).count > 0)
      feedback = params[:feedback]
      if (feedback == Feedback::WARNING && !@warninged)
        original_count = @instance.warning_count
        Feedback.create(:user_id => current_user.id,
          :instance_id => @instance.id, :value => Feedback::WARNING)
        @warninged = true

        if (original_count == 0)
          for user in get_attendees(@event)
            if (user.confirmed? && !nil_email_alias?(user.email) && user.id != current_user.id && !checked_in?(user.id, @instance.id))
              mail = SysMailer.warning_email(user, @instance)
              mail.deliver unless mail.nil?
            end
          end
        end
      elsif (feedback == Feedback::DISABLE_WARNING && @warninged)
        Feedback.where("user_id=? AND instance_id=? AND value=?",
          current_user.id, @instance.id, Feedback::WARNING).to_a.each do |f|
          f.destroy
        end
        @warninged = false
        
        if (@instance.warning_count == 0)
          for user in get_attendees(@event)
            if (user.confirmed? && !nil_email_alias?(user.email) && user.id != current_user.id && !checked_in?(user.id, @instance.id))
              mail = SysMailer.warning_email(user, @instance)
              mail.deliver unless mail.nil?
            end
          end
        end
      end

      @warning_count = @instance.warning_count
      attendee_ids = get_attendees(@event).map { |user| user.id }
      @total_count = attendee_ids.size
      @can_warn = attendee_ids.include? current_user.id
      @warning_reliability = @warning_count.to_f / [@total_count, 1].max

      if (feedback && feedback.match(Feedback::SCORE_REGEX))
        Feedback.where("user_id=? AND instance_id=? AND value like ?",
            current_user.id, @instance.id, Feedback::SCORE + ".%").to_a.each do |f|
          f.destroy
        end

        begin
          Feedback.create!(:user_id => current_user.id,
            :instance_id => @instance.id, :value => feedback)
        rescue ActiveRecord::RecordInvalid
          flash[:alert] = I18n.t 'tongshare.feedback.invalid'
        end
      end

      my_score_feedbacks = Feedback.where("user_id=? AND instance_id=? AND value like ?",
            current_user.id, @instance.id, Feedback::SCORE + ".%").to_a
      if (!my_score_feedbacks.nil? && my_score_feedbacks.size > 0)
        m = my_score_feedbacks[0].value.match Feedback::SCORE_REGEX
        @my_score = m[1].to_i
      else
        @my_score = 0
      end
      @current_score, @score_reliability = @instance.average_score_with_reliability
      @scored = @my_score > 0

      if (params[:feedback] == Feedback::CHECK_IN)
        check_in(current_user.id, @instance.id)
      elsif (params[:feedback] == Feedback::CHECK_OUT)
        check_out(current_user.id, @instance.id)
      end
      @checked_in = checked_in?(current_user.id, @instance.id)
      @check_in_count = check_in_count(@instance.id)
    end

    @current_user = current_user
    @friendly_time_range  = friendly_time_range(@event.begin, @event.end)
    @sharing = Sharing.find_last_by_shared_from_and_event_id(current_user.id, @event.id)

    @attendee_offset = (params[:offset] || 0).to_i

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @event }
    end
  end

  # GET /events/new
  # GET /events/new.xml
  def new
    @event = Event.new

    #automatically set time
    range = params[:range].blank? ? :day : params[:range].to_sym
    offset = params[:offset].blank? ? 0 : params[:offset].to_i

    case range
    when :next
        @event.begin = Time.now
    when :day
        @event.begin = Time.now + offset.days
    when :week
        @event.begin = Time.now + offset.weeks
    end

    @event.end = @event.begin + 30.minutes
    time_ruby2selector(@event)

    @event.rrule_days = [Date.today.wday]
    @event.rrule_count = 16  #TODO: how to set default value?

    @event.creator_id = current_user.id
    authorize! :new, @event

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @event }
    end
  end

  # GET /events/1/edit
  def edit
    @event = Event.find(params[:id])
    authorize! :edit, @event
    
    time_ruby2selector(@event)
  end

  # POST /events
  # POST /events.xml
  def create
    @event = Event.new(params[:event])
    time_selector2ruby(@event)

    @event.creator_id = current_user.id
    authorize! :create, @event
    
    ret = @event.save
    respond_to do |format|
      if ret
        format.html { redirect_to(@event, :notice => I18n.t('tongshare.event.created', :name => @event.name)) }
        format.xml  { render :xml => @event, :status => :created, :location => @event }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /events/1
  # PUT /events/1.xml
  def update
    @event = Event.find(params[:id])
    authorize! :update, @event
    
    time_selector2ruby(@event)
    
    ret = @event.update_attributes(params[:event])
    
    respond_to do |format|
      if ret
        format.html { redirect_to(@event, :notice => I18n.t('tongshare.event.updated', :name => @event.name)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.xml
  def destroy
    @event = Event.find(params[:id])
    
    authorize! :destroy, @event

    @event.destroy

    respond_to do |format|
      format.html { redirect_to(events_url) }
      format.xml  { head :ok }
    end
  end



end

