class UserExtra < ActiveRecord::Base
  has_attached_file :avatar, :styles => { :medium => "300x300", :thumb => "100x100"}

  include SiteConnectHelper
  attr_accessible :user_id, :name, :mobile, :public, :renren_id, :renren_url, :reject_warning_flag,
    :photo_url, :department, :hide_profile, :profile_status, :avatar, :address, :phone, :org, :qq, :msn, :fetion, :gtalk, :city, :gender
  belongs_to :user

  validates_format_of :renren_id, :with => /\A((id:[0-9]+)|(domain:.+))\Z/, :allow_nil => true, :allow_blank => true

  def renren_url
    logger.debug errors.to_yaml
    if errors[:renren_id].nil? || errors[:renren_id].empty?
      generate_renren_url(self.renren_id)
    else
      self.renren_id
    end
  end

  def renren_url=(str)
    ret = parse_renren_url(str)
    logger.debug "test: " + ret.to_yaml
    self.renren_id = ret.nil? ? str : ret #when illegal, write str to renren_id. That will raise validation error as expected.
  end

end
