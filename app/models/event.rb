


require 'gcal4ruby'

class Event < ActiveRecord::Base

  MAX_INSTANCE_COUNT = 64
  SECONDS_OF_A_DAY = 24 * 60 * 60

  RRULE_END_BY_NEVER = 0  #won't store into database, currently not supported
  RRULE_END_BY_COUNT = 1  #won't store into database
  RRULE_END_BY_DATE = 2   #won't store into database

  PUBLIC_TOKEN = "public"

  
  # In order to make Event.new(:creator_id => creator_id) work, attr_accessible :creator_id
  # seems to be necessary!
  attr_accessible :name, :begin, :end, :location, :extra_info, :rrule, :creator_id, :share_token
  attr_accessible :rrule_interval, :rrule_frequency, :rrule_days, :rrule_count, :rrule_repeat_until, :rrule_end_condition

  belongs_to :creator, :class_name => "User"
  has_many :acceptances, :foreign_key => "event_id", :dependent => :destroy
  has_many :sharings, :foreign_key => "event_id", :dependent => :destroy
  has_many :instances, :foreign_key => "event_id", :dependent => :destroy
  has_many :reminders, :dependent => :destroy
  has_many :greetings, :dependent => :destroy
  has_many :group_sharings, :through => :sharings

  #TODO validates
  validates :name, :begin, :creator_id, :presence => true
  validates_numericality_of :rrule_count, :allow_nil => true, :only_integer => true, :greater_than_or_equal_to => 1, :less_than_or_equal_to => MAX_INSTANCE_COUNT
  validates_inclusion_of :rrule_frequency, :in => GCal4Ruby::Recurrence::DUMMY_FREQS

  before_destroy :set_removed_event

  def set_removed_event
    RemovedEvent.create!(:event_id => self.id, :creator_id => self.creator_id, :name => self.name)
  end

  include SharingsHelper
  #
  #

  def save
    Location.create!(:name => self.location) if (Location.find_by_name(self.location).nil?)
    self.share_token = PUBLIC_TOKEN if self.creator.public? # Public user's events are public

    #check rrule_days
    if self.rrule_frequency == GCal4Ruby::Recurrence::WEEKLY_FREQUENCE
      if self.rrule_days.empty?
        self.rrule_days = [Date.today.wday]
      end
    else
      self.rrule_days = []
    end

    #check repeat_end_condition
    if self.rrule_end_condition == RRULE_END_BY_NEVER || self.rrule_end_condition == RRULE_END_BY_COUNT
      self.recurrence.repeat_until = nil
      logger.debug "set repeat_until to nil"
    end

    if self.rrule_end_condition == RRULE_END_BY_NEVER || self.rrule_end_condition == RRULE_END_BY_DATE
      self.recurrence.count = nil
      logger.debug "set count to nil"
    end
    
    #generate rrule
    logger.debug self.recurrence.to_yaml
    logger.debug "end cond: " + self.rrule_end_condition.to_yaml
    logger.debug "repeat_until: " + self.recurrence.repeat_until.to_yaml
    logger.debug "count: " + self.recurrence.count.to_yaml
    ##

    self.rrule = self.recurrence.rrule
    logger.debug self.rrule.to_yaml

    return false if !valid?
    drop_instance
    ret = generate_instance
    if !ret
      #TODO repeat_until
      return false
    end
    #seems no improving...
    #Instance.transaction do
    ret = super

    #reload instances
    self.instances(true)
    #regenerate reminder_queues
    self.reminders(true).each do |r|
      r.save
    end

    logger.debug errors.to_yaml
    return false if !ret
    #TODO edit each for better performance?
    return true
  end

#  def update_attributes(vars = {})
#    #"super" will call "save", so no more for rrule
#
#    ret = super
#    return false if !ret
#    #TODO edit each for better performance?
#    #drop_instance
#    #generate_instance
#    #modified by Wander: do not do these two operations because update_attributes calls "save"
#  end

  #TODO untested
  def add_sharing(current_user_id, extra_info, user_ids, user_priority = UserSharing::PRIORITY_INVITE, groups = [])
    # I think this won't work since sharing has no attr_accessor!
    s = self.sharings.new(:shared_from => current_user_id, :extra_info => extra_info)
    #ids = user_ids.split(%r{[,;]\s*}
    nodup_user_ids = user_ids - find_duplicated_sharing(current_user_id, self.id, user_ids)
    uids = User.where(:id => nodup_user_ids)
    #FIXME true or false? # SpaceFlyer: true, because maybe all invited members are new emails
    #return false if uids.empty?
    uids.each do |id|
      s.add_user_sharing(id.id, user_priority)
    end
    dup_group_ids = find_duplicated_group_sharing(current_user_id, self.id, groups)
    for group in groups
      next if (dup_group_ids.include? group.id)
      s.add_group_sharing(group.id)
    end
    s.save
  end

  def query_instance(time_begin, time_end)
    self.instances.where("begin >= ? AND end <= ?", time_begin, time_end).order("begin")
  end

  def decide_by_user(user_id, decision = Acceptance::DECISION_ACCEPTED)
    accs = self.acceptances.where("user_id = ?", user_id)
    if accs.exists?
      acc = accs.first
      acc.decision = decision
    else
      acc = self.acceptances.build(:user_id => user_id, :decision => decision)
    end
    acc.save
  end

  #TODO group
  def open_to_user?(user_id)
       self.creator_id == user_id \
    || Acceptance.where(:event_id => self.id, :user_id => user_id, :decision => Acceptance::DECISION_ACCEPTED).exists? \
    || UserSharing.joins(:sharing).where(:user_id => user_id, 'sharings.event_id' => self.id).exists?
  end

  def add_reminder(value, time_type = Reminder::TIME_DAY, method_type = Reminder::METHOD_EMAIL)
    r = self.reminders.new(
      :method_type => method_type,
      :value => value,
      :time_type => time_type
    )
    r.save
    # force reload reminders
    self.reminders(true)
    true
  end

  #virtual fields for recurrence logic
  #these fields will simplify and unify new/edit in controllers
  #TODO: validates
  def recurrence
    if !defined? @recurrence
      @recurrence = GCal4Ruby::Recurrence.new
      @recurrence.from_rrule(self.rrule) unless self.rrule.blank?
    end

    @recurrence
  end

  def rrule_frequency
    ret = self.recurrence.frequency
    ret ||= GCal4Ruby::Recurrence::NONE_FREQUENCY
    ret
  end

  def rrule_frequency=(f)
    # will be checked in GCal4Ruby::Recurrence::frequency=
    self.recurrence.frequency = f
  end

  def rrule_interval
    self.recurrence.interval || 1
  end

  def rrule_interval=(i)
    self.recurrence.interval = i.to_i
  end

  def rrule_days
    ret = self.recurrence.get_days
    ret = [Date.today.wday] if ret.empty?
    ret
  end

  def rrule_days=(days)
    ret = []
    days.each do |d|
      ret << d.to_i unless d.blank?
    end
    self.recurrence.set_days(ret)
  end

  def rrule_count
    self.recurrence.count || 1
  end

  def rrule_count=(count)
    self.recurrence.count = count.to_i
  end

  def rrule_repeat_until
    self.recurrence.repeat_until
  end

  def rrule_repeat_until=(date_str)
    begin
      date = Date.parse(date_str)
    rescue ArgumentError => e
      date = nil
    end
    
    self.recurrence.repeat_until=date
  end

  def rrule_end_condition
    if !defined? @rrule_end_condition
      if self.recurrence.count.nil? && self.recurrence.repeat_until.nil?
        RRULE_END_BY_NEVER
      elsif !self.recurrence.repeat_until.nil?
        RRULE_END_BY_DATE
      else
        RRULE_END_BY_COUNT
      end
    else
      @rrule_end_condition
    end
  end

  def rrule_end_condition=(cond_str)
    @rrule_end_condition = cond_str.to_i
    #will check consistency in "save"
  end

  def recurring?
    !self.rrule.blank?
  end

  def get_or_create_share_token
    if (self.share_token.nil?)
      self.share_token = rand(36**8).to_s(36) # ref http://blog.logeek.fr/2009/7/2/creating-small-unique-tokens-in-ruby
      self.save!
    end
    self.share_token
  end

  def public?
    return get_or_create_share_token == PUBLIC_TOKEN
  end

  def set_public
    self.share_token = PUBLIC_TOKEN
    self.save!
  end

  def set_private
    self.share_token = rand(36**8).to_s(36)
    self.save!
  end
  
  protected
 
  def drop_instance
    if self.instances
      self.instances.each do |i|
        i.destroy
      end
    end
  end
  
  def generate_instance
    if self.rrule_frequency == GCal4Ruby::Recurrence::NONE_FREQUENCY
      i = self.instances.build(
        :override => nil,
        :name => self.name,
        :location => self.location,
        :extra_info => self.extra_info,
        :begin => self.begin,
        :end => self.end,
        :creator_id => self.creator_id
        )
      #i.save
    else
      #rec = GCal4Ruby::Recurrence.new
      #rec.from_rrule(self.rrule) # rec.load('RRULE:' + self.rrule) will encounter bug since self.rrule may begin with 'RRULE:'      
      #modified by Wander
      rec = self.recurrence
      interval = self.rrule_interval
      count = 0
      if rec.frequency == 'DAILY'
        while 1
          self.instances.build(
            :name => self.name,
            :location => self.location,
            :extra_info => self.extra_info,
            :begin => self.begin + count * interval * SECONDS_OF_A_DAY,
            :end => self.end + count * interval * SECONDS_OF_A_DAY,
            :override => false,
            :index => count,
            :creator_id => self.creator_id
          )
          count += 1
          break if !rec.count.nil? and count >= rec.count
          break if !rec.repeat_until.nil? and self.begin + count * interval * SECONDS_OF_A_DAY > rec.repeat_until
          #return false if count > MAX_INSTANCE_COUNT
          #modified by Wander
          if count > MAX_INSTANCE_COUNT
            report_count_too_much
            return
          end
        end
        
      elsif rec.frequency == 'WEEKLY'
        now = self.begin
        interval = 0
        interval = rec.interval - 1 if rec.interval > 1
        while 1
          if rec.day[now.wday]
            #
            self.instances.build(
              :name => self.name, 
              :location => self.location, 
              :extra_info => self.extra_info,
              :begin => now,
              :end => self.end + (now - self.begin),
              :override => false,
              :index => count,
              :creator_id => self.creator_id
            )
            #i.save
            count += 1
          end         
          break if !rec.count.nil? and count >= rec.count
          break if !rec.repeat_until.nil? and now > rec.repeat_until

          #return false if count > MAX_INSTANCE_COUNT
          #modified by Wander
          if count > MAX_INSTANCE_COUNT
            report_count_too_much
            return
          end

          now += SECONDS_OF_A_DAY # now += 1.day seems to be too slow in 1.8.7
          if now.wday == 0 # now.sunday? is too new for ruby1.8.7
            now += interval * 7 * SECONDS_OF_A_DAY
          end

        end
        
      elsif rec.frequency == 'MONTHLY'
        #TODO
      elsif rec.frequency == 'YEARLY'
        #TODO
      else
        logger.debug "#{__method__}:unknown frequency: #{rec.frequency}"
      end
      logger.debug "#{__method__}:instance generated:" + self.instances.size.to_s
    end
    
    true
  end

  def report_count_too_much
    logger.debug "instance too much"
    if self.recurrence.count.nil?
      errors.add :rrule_repeat_until, :too_late, :max_count => MAX_INSTANCE_COUNT
    else
      errors.add :rrule_count, :too_much, :max_count => MAX_INSTANCE_COUNT
    end
    return false
  end

end
