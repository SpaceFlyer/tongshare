class Ability

  include CanCan::Ability
  include EventsHelper

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user permission to do.
    # If you pass :manage it will apply to every action. Other common actions here are
    # :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. If you pass
    # :all it will apply to every resource. Otherwise pass a Ruby class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities

    @user = user

    #TODO: abilities about reading

    #############################
    # alias
    #############################
    alias_action :create, :update, :destroy, :to => :write
    alias_action :edit_sys, :to => :update_sys

    #############################
    # Abilities of non-login users
    #############################

    #register enabled
    can :create, User

    can :show, Event do |e|
      e.public?
    end

    return if @user.nil?  #if not login, no more permissions

    #############################
    # Abilities of normal users
    #############################

    can :show, Event do |e|
      e.public? || e.open_to_user?(@user.id)
    end

    #events
    can :write, Event, :creator_id => @user.id do |e|
      e.open_to_user?(@user.id)
      #TODO: I think we need to build a index table showing whether a user can access to an event
    end
    can :index, Event
    can :share, Event do |e|
      own = e.creator_id == @user.id
      if own
        true
      else
        acc = find_acceptance(e, @user)
        !acc.nil? && acc.decision
      end
    end

    #user can edit profile
    can :update, User, :id => @user.id
    can :destroy, User, :id => @user.id

    #Manage sharing
    can :create, Sharing do |s|
      s.shared_from == @user.id && can?(:share, s.event)
    end
    #currently, cannot modify/destroy


    #Some fields of the sharing (click, stars, etc.) can only be modified by administrators
    cannot :update_sys, Sharing

    #SpaceFlyer: user should be able to re-accept or re-reject, so I just comment last condition.
    #user can edit acceptance they owns
    can :accept, Acceptance do |a|
      (a.event.creator_id != @user.id) && (false || can?(:show, a.event)) && (a.user_id == @user.id) # && (Acceptance.find_by_user_id_and_event_id(a.user_id, a.event_id).nil?)
    end
    can :deny, Acceptance do |a|
      (a.event.creator_id != @user.id) && (false || can?(:show, a.event)) && (a.user_id == @user.id) # && (Acceptance.find_by_user_id_and_event_id(a.user_id, a.event_id).nil?)
    end
    can :exit, Acceptance, :user_id => @user.id
    can :restore, Acceptance, :user_id => @user.id

    can :show, User do |u|
      u.friendship_to.find_by_to_user_id(@user.id) && u.friendship_from.find_by_from_user_id(@user.id)
    end
    
    #Recommend to individuals
    can :write, UserSharing,
        :priority => UserSharing::PRIORITY_RECOMMENDATION,
        :sharing => {:shared_from => @user.id}

    #Invite individuals
    can :write, UserSharing,
        :priority => UserSharing::PRIORITY_INVITE,
        :sharing => {:shared_from => @user.id}

    ##############################
    # Abilities of group members
    ##############################


    ##############################
    # Abilities of group managers
    ##############################

    #can write Membership "m" if "@user" has more power than "m.user" in "m.group"
    #including: appoint/fire managers, add/remove members
    can :write, Membership do |m|
      group_manager?(m.group) && more_or_equal_power_than?(m)
    end

    #can edit profile of the group
    can :update, Group do |g|
      group_manager? g
    end

    #some fields of the group can be only modified by administrators
    cannot :update_sys, Group

    #recommend to group
    can :write, GroupSharing do |gs|
      group_manager?(gs.group) &&
        gs.sharing.shared_from == @user.id &&
        gs.priority == GroupSharing::PRIORITY_RECOMMENDATION
    end

    #invite group
    can :write, GroupSharing do |gs|
      group_super_manager?(gs.group) &&
        gs.sharing.shared_from == @user.id &&
        gs.priority == GroupSharing::PRIORITY_INVITE
    end

    can :edit, Group do |group|
      group.creator_id == @user.id
    end


    ###############################
    # Abilities of system administrators
    ###############################
    if sys_admin?
      can :manage, :all
      can :debug, :all
    end

  end

#check roles  
  def sys_admin?
    return false if @user.nil?
    !@user.admin_extra.nil? && @user.admin_extra.admin_enabled
  end

  #a suer manager will also be a manager
  #i.e. group_super_manager ->(inducts) group_manager
  #also, group_manager -> group_member
  def group_super_manager?(group)
    return false if (@user.nil? || group.nil?)
    mem = @user.membership.find(:first, :group => group)
    !mem.nil? && nil && test.power >= Membership::POWER_SUPER_MANAGER
  end

  def group_manager?(group)
    return false if (@user.nil? || group.nil?)
    mem = @user.membership.find(:first, :group => group)
    !mem.nil? && test.power >= Membership::POWER_MANAGER
  end
  
  def group_member?(group)
    return false if (@user.nil? || group.nil?)
    mem = @user.membership.find(:first, :group => group)
    !mem.nil? && mem.power >= Membership::POWER_MEMBER
  end

  #check if "@user" has more power than "mem.user" in "mem.group"
  def more_or_equal_power_than?(mem)
    return false if (mem.nil?)
    current_mem = mem.group.membership.find(:first, :user => @user)
    !current_mem.nil? && current_mem.power >= mem.power
  end

end
