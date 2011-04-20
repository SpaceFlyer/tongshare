module SharingsHelper
  def find_duplicated_sharing(current_user_id, event_id, user_ids)
    responsed_ids = Acceptance.where('user_id in (?) AND event_id=?', user_ids, event_id).to_a.map{ |acc| acc.user_id }
    responsed_ids << Event.find(event_id).creator_id
    query = UserSharing.joins(:sharing).where('sharings.shared_from' => current_user_id, 'sharings.event_id' => event_id, :user_id => user_ids).to_a
    query.map! {|q| q.user_id}
    query << current_user_id if (!query.include?(current_user_id) && user_ids.include?(current_user_id))
    return (query | responsed_ids)
  end
  
  def find_duplicated_group_sharing(current_user_id, event_id, groups)
    responsed_ids = GroupSharing.joins(:sharing).where('sharings.event_id' => event_id, :group_id => groups.map{|g| g.id}).to_a.map{|gs| gs.group_id}
    return (responsed_ids)
  end

  #parse the raw string the user has input
  #return an array containing a hash {:type => xxx, :login_value => xxx}
  def parse_sharings_raw(str)
    result = []

    #TODO: copied from user_identifier. Consider a better code style, like putting them in configurations.
    employee_no_pattern = /[0-9]{10}/  #TODO: should get patterns for different schools
    mobile_pattern = /1[0-9]{10}/
    email_pattern = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}/

    elements = str.split(/(\s|,|;|\n)+/)
    for elem in elements
      next if elem.empty?
      m = nil
      if (m = elem.match(email_pattern))
        type = UserIdentifier::TYPE_EMAIL
      elsif (m = elem.match(mobile_pattern))
        type = UserIdentifier::TYPE_MOBILE
      elsif (m = elem.match(employee_no_pattern))
        type = UserIdentifier::TYPE_EMPLOYEE_NO
      else
        type = nil
      end
      result << {:type => type, :login_value => m ? m[0] : elem}
    end

    result
  end

  #find all acceptances whose owner is invited by "user" to attend "event". If one member is in multiple sharings, this function will combine them.
  def find_invited_feedback(event_id, invitor_id)

    result = {:counter => {:accepted => 0, :rejected => 0, :undecided => 0}, :data => []}

    user_ids = Set.new
    sharings = Sharing.all(:conditions => ['event_id = ? AND shared_from = ?', event_id, invitor_id], :include => :user_sharings)
    return nil if sharings.empty?
    sharings.each do |s| #we consume that a user won't sharing the same event so many times
      user_ids.merge s.user_sharings.collect {|us| us.user_id}
    end

    acceptances = Acceptance.all(:conditions => ['event_id = ? AND user_id IN (?)', event_id, user_ids.to_a], :include => :user, :order => 'decision')
    acceptances.each do |acc|
      result[:data] << {:user => acc.user, :decision => acc.decision}
      if acc.decision == true
        result[:counter][:accepted] += 1
      else
        result[:counter][:rejected] += 1
      end
      user_ids.delete(acc.user_id)
    end

    undecided = User.all(:conditions => ['id IN (?)', user_ids.to_a])
    undecided.each do |u|
      result[:data] << {:user => u, :decision => nil}
      result[:counter][:undecided] += 1
    end

    result
  end

end
