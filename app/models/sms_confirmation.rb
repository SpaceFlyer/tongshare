class SmsConfirmation < ActiveRecord::Base
  attr_accessible :user_id, :token, :confirmed
  belongs_to :user
end
