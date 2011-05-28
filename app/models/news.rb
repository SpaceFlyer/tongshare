class News < ActiveRecord::Base
  ACTION_DESTROY = 'destroy'
  ACTION_EDIT = 'edit'
  ACTION_PROFILE = 'profile'
  ACTION_JOIN = 'join'
  ACTION_CREATE = 'create'
  ACTION_CHECK = 'check'
  ACTION_QUIT = 'quit'

  attr_accessible :user_id, :action, :target_event_id

  belongs_to :user
  belongs_to :target_event, :class_name => 'Event'
end
