module CalCicHelper
  XML_PATH = "http://cal.cic.tsinghua.edu.cn:80/cal_pub/cal_pub/calendarXml.action"
  require 'net/http'
  require 'rexml/document'
  def self.import_all(user_id = nil)
    if user_id.nil?
        query = UserIdentifier.find_all_by_login_value 'tsinghua.edu.cn.9999100100'
        user_id = query.first.user_id
    end
    url = URI.parse(XML_PATH)
    post_args = {'calendar.startDate' => '20101230T053000Z', 'calendar.endDate' => '20111230T053000Z'}
    resp, data = Net::HTTP.post_form(url, post_args)

    doc = REXML::Document.new(data)
    events = []
    doc.elements.each('calendar/event') do |e|
      name = e.get_elements('summary').first.text
      start_time = Time.parse(e.get_elements('startTime').first.text).getlocal
      end_time = Time.parse(e.get_elements('endTime').first.text).getlocal
      # won't need
      # if end_time - start_time == 24 * 60 * 60 && end_time.hour == 0 && end_time.min == 0 && end_time.sec == 0
      #   end_time -= 1
      # end
      location = e.get_elements('location').first.text
      location = '' if location.nil?
      extra_info = e.get_elements('description').first.text
      query = Event.find_all_by_creator_id_and_begin_and_end_and_name_and_location_and_extra_info(
        user_id, start_time, end_time, name, location, extra_info
      )
      if query.size == 0
        v = Event.new(
          :creator_id => user_id,
          :begin => start_time,
          :end => end_time,
          :name => name,
          :location => location,
          :extra_info => extra_info,
          :rrule_frequency => RruleHelper::Recurrence::NONE_FREQUENCY)
        v.save
      else
        v = query.first
      end
      events << v.id
    end
    a = Event.find_all_by_creator_id user_id
    a.each do |e|
      if !events.include?(e.id)
        puts 'event id = ' + e.id.to_s + ' destroy'
        e.destroy
      else
        puts 'event id = ' + e.id.to_s + ' remain'
      end
    end
  end

  def destroy_all_events_of_user(user_id)
    a = Event.find_all_by_creator_id user_id
    a.each do |e|
      e.destroy
    end
  end

end