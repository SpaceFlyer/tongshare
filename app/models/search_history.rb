class SearchHistory < ActiveRecord::Base
  attr_accessible :param, :user_id
  belongs_to :user
  serialize :param

  def self.get_last(user_id)
    self.find_last_by_user_id(user_id)
  end
end
