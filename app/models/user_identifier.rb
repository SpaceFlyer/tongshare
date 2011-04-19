# encoding: UTF-8
# Type should be in {"employee_no", "mobile", "email"}
class UserIdentifier < ActiveRecord::Base
  extend UsersHelper
  include UsersHelper

  MAX_VALUE_LENGTH = 128
  TYPE_EMPLOYEE_NO = 'employee_no'
  TYPE_MOBILE = 'mobile'
  TYPE_EMAIL = 'email'
  TYPE_EMPLOYEE_NO_DUMMY = 'employee_no_dummy'  #automatic created user when sharing
  TYPE_EMAIL_DUMMY = 'email_dummy'
  TYPE_MOBILE_DUMMY = 'mobile_dummy'
  
  belongs_to :user
  
  validates :login_value, :login_type, :presence => true
  validates_length_of :login_value, :maximum => MAX_VALUE_LENGTH, :message => "长度不能超过#{MAX_VALUE_LENGTH}字节" #TODO: several issues with i18n
  
  # Currently, only three types are supported
  validates_format_of :login_type, :with => /(#{TYPE_EMPLOYEE_NO})|(#{TYPE_MOBILE})|(#{TYPE_EMAIL})|(#{TYPE_EMPLOYEE_NO_DUMMY})/

  validates_uniqueness_of :login_value, :scope => :login_type   #it seems this validates uniqueness of [:value, :type]
  #TODO: "Value has already been taken" -> "xxx has already been taken"
  validate :value_format_check

  attr_accessible :login_value, :login_type, :confirmed, :user, :user_id

  
  def value_format_check
    case login_type
    when TYPE_EMPLOYEE_NO, TYPE_EMPLOYEE_NO_DUMMY
      errors.add(:login_value, :employee_no_invalid) if login_value.match(/^#{company_domain(self.user)}\.[0-9]{10}$/).nil?   #目前只考虑清华. TODO: 工作证格式？
    when TYPE_MOBILE
      errors.add(:login_value, :mobile_invalid) if login_value.match(/^1[0-9]{10}$/).nil?
    when TYPE_EMAIL
      #errors.add(:email, :invalid) if login_value.match(/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/).nil?
    end
  end

  #value does not contains tsinghua.edu.cn. return User or nil
  def self.find_user_by(login_type, login_value)
    ui = UserIdentifier.find_by(login_type, login_value)
    return nil if ui.nil?
    return ui.user
  end

  #value does not contains tsinghua.edu.cn. return UserIdentifier or nil
  def self.find_by(login_type, login_value)
    login_value = company_domain + "." + login_value if login_type == TYPE_EMPLOYEE_NO
    ui = UserIdentifier.find(:first, :conditions => ["login_type = ? AND login_value = ?", login_type, login_value])
    return ui
  end
end
