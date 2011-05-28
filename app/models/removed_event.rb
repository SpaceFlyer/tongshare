class RemovedEvent < ActiveRecord::Base
  attr_accessible :event_id, :creator_id, :name

  belongs_to :creator, :class_name => "User"
end
