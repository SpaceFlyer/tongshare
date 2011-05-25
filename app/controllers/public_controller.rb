require 'htmlentities'

class PublicController < ApplicationController
  include EventsHelper
  
  # JSON has some problem with UTF8 Chinese character...
  # Use XML (it's verified to work well with UTF8 Chinese character if you encounter that problem
  # Sample 1(initial request in json): http://localhost:3000/public/get_diff.json?id=tsinghua.edu.cn.9999100100
  # Sample response 1: {"events":[{"event":{"name":"\u6d4b\u8bd5\u6d3b\u52a8","begin":"2011-02-27T17:44:00+08:00","location":"\u516d\u6559;6C300","created_at":"2011-02-27T17:44:18+08:00","updated_at":"2011-02-27T18:37:34+08:00","rrule":"","id":1,"end":"2011-02-27T18:14:00+08:00","creator_id":8,"extra_info":"\u5730\u70b9\u7528\u5206\u53f7';'\u5206\u9694\u5927\u5730\u70b9\u548c\u5c0f\u5730\u70b9"}}],"time_now":"2011-02-27T18:37:40+08:00"}
  # Sample 2(initial request in xml): http://localhost:3000/public/get_diff.xml?id=tsinghua.edu.cn.9999100100
  # Sample response 2:
  #<?xml version="1.0" encoding="UTF-8"?>
  #<hash>
  #  <time-now type="datetime">2011-02-27T18:38:50+08:00</time-now>
  #  <events type="array">
  #    <event>
  #      <begin type="datetime">2011-02-27T09:44:00Z</begin>
  #      <name>&#27979;&#35797;&#27963;&#21160;</name>
  #      <created-at type="datetime">2011-02-27T09:44:18Z</created-at>
  #      <location>&#20845;&#25945;;6C300</location>
  #      <rrule></rrule>
  #      <updated-at type="datetime">2011-02-27T10:37:34Z</updated-at>
  #      <creator-id type="integer">8</creator-id>
  #      <end type="datetime">2011-02-27T10:14:00Z</end>
  #      <id type="integer">1</id>
  #      <extra-info>&#22320;&#28857;&#29992;&#20998;&#21495;';'&#20998;&#38548;&#22823;&#22320;&#28857;&#21644;&#23567;&#22320;&#28857;</extra-info>
  #    </event>
  #  </events>
  #</hash>
  # Sample 3(diff request in json): http://localhost:3000/public/get_diff.json?id=tsinghua.edu.cn.9999100100&last_update=2011/3/1
  # Sample response 3: {"events":[],"time_now":"2011-02-27T18:01:50+08:00"}
  #
  def get_diff
    id_value = params[:id]
    ui = UserIdentifier.find_by_login_value(id_value)
    if ui.nil?
      respond_to do |format|
        format.html { render :text => "user not existed" }
        format.xml { render :text => "user not existed" }
        format.json { render :text => "user not existed" }
      end
      return
    end
    
    user = ui.user
    if user.user_extra.nil? || !user.user_extra.public
      respond_to do |format|
        format.html { render :text => "user not public" }
        format.xml { render :text => "user not public" }
        format.json { render :text => "user not public" }
      end
      return
    end

    if (params[:last_update])
      last_update = Time.parse(params[:last_update]).utc
    else
      last_update = 0
    end

    events = Event.where("creator_id=? AND updated_at>?", user.id, last_update).to_a
    ret_events = []
    for event in events
      ret_event = {}
      ret_event[:id] = event.id
      ret_event[:created_at] = event.created_at
      ret_event[:updated_at] = event.updated_at
      ret_event[:name] = event.name
      ret_event[:begin] = event.begin
      ret_event[:end] = event.end
      ret_event[:location] = event.location
      ret_event[:extra_info] = event.extra_info
      ret_event[:rrule] = event.rrule
      ret_event[:creator_id] = event.creator_id
      ret_event[:share_token] = event.share_token
      ret_event[:rrule_interval] = event.rrule_interval
      ret_event[:rrule_frequency] = event.rrule_frequency
      ret_event[:rrule_days] = event.rrule_days
      ret_event[:rrule_count] = event.rrule_count
      ret_event[:rrule_repeat_until] = event.rrule_repeat_until
      ret_event[:rrule_end_condition] = event.rrule_end_condition
      ret_event[:friendly_time_range] = hack_time_string(friendly_time_range(event.begin, event.end))
      ret_event[:friendly_begin_time] = hack_time_string(I18n.l(event.begin, :format => :time_only))
      ret_event[:friendly_begin_time] = "全天" if (ret_event[:friendly_begin_time] == "00:00")
      if (ret_event[:friendly_time_range].include?("上午") && ret_event[:friendly_time_range].include?("下午"))
        ret_event[:friendly_time_range].gsub! /上午/, "全天"
        ret_event[:friendly_time_range].gsub! /下午/, "全天"
        ret_event[:friendly_begin_time].gsub! /上午/, "全天"
      end
      ret_events << ret_event
    end
    removed_events = RemovedEvent.where('creator_id=? AND updated_at>?', user.id, last_update).to_a.map{ |re| re.event_id }
    result = {:time_now => Time.now.localtime, :events => ret_events, :delete => removed_events}
    respond_to do |format|
      format.html { render :text => result.to_json }
      format.json { render :json => result }
      if (params[:disable_escape] && params[:disable_escape] == 'true')
        format.xml do
          coder = coder = HTMLEntities.new
          xml_result = result.to_xml
          xml_result.gsub!(/&#\d+;/) { |m| coder.decode(m)}
          render :text => xml_result
        end
      else
        format.xml { render :xml => result }
      end
    end
  end

  def hack_time_string(s)
    s = s.gsub /08:05/, '上午'
    s = s.gsub /13:05/, '下午'
    s = s.gsub /18:05/, '晚上'
    s = s.gsub /今天/, I18n.l(Time.now, :format => :date_only)
    s = s.gsub /明天/, I18n.l(Time.now+1.day, :format => :date_only)
    s = s.gsub /后天/, I18n.l(Time.now+2.day, :format => :date_only)
  end

  def show_public_group
    group_id = params[:group_id]
    @group = Group.find(group_id)
    redirect_to 'events/', :alert => '该公共群组不存在' if (!@group || @group.privacy != Group::PRIVACY_PUBLIC)

    params[:range] = "next" unless ["next", "day", "week"].include?(params[:range])
    params[:offset] ||= 0
    params[:limit] ||= 10
    @range = params[:range].to_sym
    @offset = params[:offset].to_i
    @limit = params[:limit].to_i

    if @range == :next
      @instances = query_next_group_instance_includes_event(Time.now, @limit + 1, @group.id, @offset)
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

      @instances = query_all_group_instance_includes_event(from.to_time, to.to_time, @group.id)
    end

    respond_to do |format|
      format.html # index.html.erb
      #format.xml  { render :xml => @instances }
    end
  end

  def show_public_user
    user_id = params[:user_id]
    @user = User.find(user_id)
    redirect_to 'events/', :alert => '该公共用户不存在' if (!@user || !@user.user_extra || !@user.user_extra.public)

    @user_extra = @user.user_extra
    if @user_extra
      @photo_url = @user_extra.photo_url
    end

    params[:range] = "next" unless ["next", "day", "week"].include?(params[:range])
    params[:offset] ||= 0
    params[:limit] ||= 10
    @range = params[:range].to_sym
    @offset = params[:offset].to_i
    @limit = params[:limit].to_i

    if @range == :next
      @instances = query_next_accepted_instance_includes_event(Time.now, @limit + 1, @user.id, @offset)
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

      @instances = query_all_accepted_instance_includes_event(from.to_time, to.to_time, @user.id)
    end

    respond_to do |format|
      format.html # index.html.erb
      #format.xml  { render :xml => @instances }
    end
  end

  def show_location
    @location = params[:location]
  end

end
