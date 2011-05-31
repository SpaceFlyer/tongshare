
# 注意！this.sharings只是由该user创建的sharing（分享）。
# this.user_sharings只是专门针对该user的sharing。
# 所有和该用户相关的分享（即分享给用户的事件）还应该包含
# 该用户所在的群组相关的this.groups.group_sharings。
#

# by Wander: add columns for devise. 

class User < ActiveRecord::Base
  include UsersHelper
  include RegistrationsExtendedHelper
  include ProfileHelper

  #NIL_EMAIL_ALIAS_DOMAIN = 'null.tongshare.com' #see registration_extended_controller

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, 
         :token_authenticatable, #for mobile auto-login
         :recoverable, :rememberable, :trackable,
         :registerable,
         :validatable,
         :confirmable, #email verify
         :authentication_keys => [:email]

  before_save :ensure_authentication_token 
       
  # Setup accessible (or protected) attributes for your model
  attr_accessible :id, :email, :password, :password_confirmation, :remember_me, :id, :user_identifier
  attr_accessible :user_extra_attributes, :admin_extra_attributes
  
  has_many :user_identifier, :dependent => :destroy
  has_many :group, :foreign_key => "creator_id", :dependent => :destroy
  has_many :membership, :dependent => :destroy
  has_many :event, :foreign_key => "creator_id", :dependent => :destroy
  has_many :acceptance, :dependent => :destroy
  has_many :sharing, :foreign_key => "shared_from", :dependent => :destroy
  has_many :user_sharing, :dependent => :destroy
  has_many :bookmark, :dependent => :destroy
  has_many :feedback, :dependent => :destroy
  has_many :friendship_to, :class_name => 'Friendship', :foreign_key => 'from_user_id', :dependent => :destroy
  has_many :friendship_from, :class_name => 'Friendship', :foreign_key => 'to_user_id', :dependent => :destroy
  has_many :greeting_from, :class_name => 'Greeting', :foreign_key => 'to_user_id', :dependent => :destroy
  has_many :greeting_to, :class_name => 'Greeting', :foreign_key => 'from_user_id', :dependent => :destroy
  has_many :removed_event, :foreign_key => 'creator_id', :dependent => :destroy
  has_many :search_histories, :dependent => :destroy
  has_one :user_extra, :dependent => :destroy
  accepts_nested_attributes_for :user_extra
  
  has_one :admin_extra, :dependent => :destroy
  has_one :google, :class_name => "GoogleToken", :dependent=> :destroy
  #FIXME hack!
  has_many :consumer_tokens, :dependent => :destroy


  #merge errors of children into this model
  validate do |user|
    user.user_identifier.each do |identifier|
      next if identifier.valid?
      identifier.errors.each do |attr, err|
        errors.add attr, err
      end
    end
  end

  after_validation :purge_useless

  def purge_useless
    errors.delete :user_identifier
  end

  #get a friendly name for the user
  def friendly_name
    if (self.user_extra)
      name = self.user_extra.name unless self.user_extra.nil?
      return name unless name.blank?
    end
    
    employee_no_rec = self.user_identifier.find_by_login_type(UserIdentifier::TYPE_EMPLOYEE_NO)
    return without_company_domain(employee_no_rec.login_value, self) unless (employee_no_rec.nil? || employee_no_rec.login_value.blank?)

    email_rec = self.user_identifier.find_by_login_type(UserIdentifier::TYPE_EMAIL)
    return email_rec.login_value unless (email_rec.nil? || email_rec.login_value.blank?)

    employee_no_rec = self.user_identifier.find_by_login_type(UserIdentifier::TYPE_EMPLOYEE_NO_DUMMY)
    return without_company_domain(employee_no_rec.login_value, self) unless (employee_no_rec.nil? || employee_no_rec.login_value.blank?)

    email_rec = self.user_identifier.find_by_login_type(UserIdentifier::TYPE_EMAIL_DUMMY)
    return email_rec.login_value unless (email_rec.nil? || email_rec.login_value.blank?)

    return "无名"

    return nil
  end

  #override devise's
  def update_with_password(params={})
    current_password = params.delete(:current_password)

    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end

    result = if (params[:password].blank? || valid_password?(current_password))
      update_attributes(params)
    else
      self.errors.add(:current_password, current_password.blank? ? :blank : :invalid)
      self.attributes = params
      false
    end

    clean_up_passwords
    result
  end

#  def active?
#    true
#  end
  
  def has_valid_email(email=nil)
    return false if (!self.confirmed? || nil_email_alias?(self.email))
    return (email.nil? || email == self.email)
  end

  def get_employee_no
    identifier = UserIdentifier.find_by_user_id_and_login_type(self.id, UserIdentifier::TYPE_EMPLOYEE_NO)
    return identifier.login_value if identifier
    return nil
  end

  def get_thu_no
    value = get_employee_no
    if (value && (m = value.match /tsinghua.edu.cn.(\d+)/))
      return m[1].to_i
    end
    return nil
  end

  PROFILE_CHECKED = 'checked'
  PROFILE_CONFIRMED = 'confirmed'

  def auto_check_profile
    user_extra = self.user_extra
    return unless (user_extra && !user_extra.hide_profile &&
        (user_extra.profile_status.nil? || user_extra.profile_status.blank?))

    user_extra.profile_status = PROFILE_CHECKED
    num_selection, renren_urls, photo_urls, department = find_profiles(self)
    if (num_selection && num_selection == 1)
      user_extra.renren_url = renren_urls[0]
      user_extra.photo_url = photo_urls[0]
      user_extra.department = department
    end
    user_extra.save!
  end

  def public?
    return self.user_extra && self.user_extra.public
  end

  def validated_emails
    result = []
    for uid in user_identifier
      result << uid.login_value if (uid.login_type == UserIdentifier::TYPE_EMAIL && uid.confirmed)
    end
    return result
  end

end
