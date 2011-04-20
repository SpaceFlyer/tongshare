class GroupsController < ApplicationController
  include SharingsHelper
  include RegistrationsExtendedHelper
  include UsersHelper
  include EventsHelper
  include GroupsHelper

  before_filter :authenticate_user!

  def add_members
    result = {:valid => [], :dummy => [], :new_email => [], :duplicated => [], :invalid => [], :parse_errored => []}

    items = parse_sharings_raw(params[:raw_string])

    if (params[:friend_id] && !params[:friend_id].blank?)
      begin
        friend = User.find(params[:friend_id].to_i)
        uid = friend.user_identifier.first
        items << {:type => :uid, :uid => uid}
      rescue ActiveRecord::RecordNotFound
      end
    end

    if (params[:group_id] && !params[:group_id].blank?)
      begin
        group = Group.find(params[:group_id].to_i)
        if (group.privacy == Group::PRIVACY_PRIVATE) # Only private groups can be invited(public group recommendation is not supported yet)
          for membership in group.membership
            user = membership.user
            uid = user.user_identifier.first
            if (uid.login_type == UserIdentifier::TYPE_EMPLOYEE_NO_DUMMY)
              items << {:type => UserIdentifier::TYPE_EMPLOYEE_NO, :login_value => uid.login_value.match(/\d+$/)[0]}
            elsif (uid.login_type == UserIdentifier::TYPE_EMAIL_DUMMY)
              items << {:type => UserIdentifier::TYPE_EMAIL, :login_value => uid.login_value}
            else
              items << {:type => :uid, :uid => uid}
            end
          end
        elsif (group.privacy == Group::PRIVACY_PUBLIC) # only show managers for public group
          for membership in group.membership
            next if membership.power != Membership::POWER_MANAGER
            user = membership.user
            uid = user.user_identifier.first
            if (uid.login_type == UserIdentifier::TYPE_EMPLOYEE_NO_DUMMY)
              items << {:type => UserIdentifier::TYPE_EMPLOYEE_NO, :login_value => uid.login_value.match(/\d+$/)[0]}
            elsif (uid.login_type == UserIdentifier::TYPE_EMAIL_DUMMY)
              items << {:type => UserIdentifier::TYPE_EMAIL, :login_value => uid.login_value}
            else
              items << {:type => :uid, :uid => uid}
            end
          end
        end
      rescue ActiveRecord::RecordNotFound
      end
    end

    for item in items
      if item[:type].nil?
        result[:parse_errored] << item[:login_value]
        next
      end

      ui = item[:type] == :uid ? item[:uid] : UserIdentifier.find_by(item[:type], item[:login_value])
      if !ui.nil?
        begin
          name = (ui.user.user_extra.name) + (item[:login_value] ? "(#{item[:login_value]})" : "")
        rescue Exception
          name = item[:login_value]
        end
        data_entry = {:id => ui.user_id, :name => name, :conflict => []}  #do not expose user_friendly_name or attackers can enumerate 学号/姓名 pair by add sharings.

        result[:valid] << data_entry
      elsif item[:type] == UserIdentifier::TYPE_EMPLOYEE_NO
        result[:dummy] << item[:login_value]
      elsif item[:type] == UserIdentifier::TYPE_EMAIL
        result[:new_email] << item[:login_value]
      else
        result[:invalid] << item[:login_value]
      end
    end

    @json = result.to_json

    respond_to do |format|
      format.js
    end
  end

  def set_members
    members = []
    #prepare dummy users
    if !params[:dummy].nil?
      params[:dummy].each do |employee_no|
        dummy = check_or_create_dummy_user(employee_no, company_domain)
        #if an illegal employee_no is submitted in params[:dummy], check_or_create_dummy_user will raise exceptions since it calls User.save! and the value won't pass validation.
        members << dummy.id
      end
    end
    if !params[:new_email].nil?
      params[:new_email].each do |new_email|
        dummy = check_or_create_general_dummy_user(UserIdentifier::TYPE_EMAIL, UserIdentifier::TYPE_EMAIL_DUMMY, new_email)
        #if an illegal employee_no is submitted in params[:dummy], check_or_create_dummy_user will raise exceptions since it calls User.save! and the value won't pass validation.
        members << dummy.id
      end
    end

    #add normal users
    if !params[:members].nil?
      params[:members].each do |id|
        members << id.to_i
      end
    end

    if (params[:group_name] && !params[:group_name].blank?)
      if (current_user.public?)
        group = query_or_create_public_group(params[:group_name], current_user)
      else
        group = query_or_create_group_via_name_and_creator_id(params[:group_name], current_user.id)
      end
      authorize! :edit, group
      if (params[:delete])
        group.destroy
        flash[:notice] = '操作成功'
        redirect_to '/groups/'
        return
      end
      group_members = members.map do |member_id|
        {:user_id => member_id, :power => Membership::POWER_MEMBER}
      end

      if (current_user.public?)
        group.set_managers(group_members)
      else
        group.set_members(group_members)
      end
      group.save!
      flash[:notice] = '操作成功'
    else
      flash[:alert] = '群组名不能位空'
    end
    redirect_to '/groups/'
  end

  def index
  end

  # GET /groups/1
  # GET /groups/1.xml
  def show
    @group = Group.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.xml
  def new
    @group = Group.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])
  end

  # POST /groups
  # POST /groups.xml
  def create
    @group = Group.new(params[:group])

    respond_to do |format|
      if @group.save
        format.html { redirect_to(@group, :notice => 'Group was successfully created.') }
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update
    @group = Group.find(params[:id])

    respond_to do |format|
      if @group.update_attributes(params[:group])
        format.html { redirect_to(@group, :notice => 'Group was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
    end
  end
end
