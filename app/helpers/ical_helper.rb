module IcalHelper
  require 'ri_cal'
  require 'date'
  def to_ical_event(event)
    e = RiCal.Event do |e|
    e.dtstart = event.begin.utc
    e.dtend = event.end.utc
    e.summary = event.name
    e.description = event.extra_info if !event.extra_info.nil?
    e.location = event.location
    e.add_rrule(event.rrule.gsub(/RRULE:/, '')) if !event.rrule.nil? && event.rrule?
    end
  end

  def to_ical_calendar_from_user_events(user_id)
    events = Event.find_all_by_creator_id user_id
    cal = RiCal.Calendar do |cal|
      events.each do |e|
        cal.add_subcomponent(to_ical_event(e))
      end
    end
  end

  def to_ics(component)
    component.to_s
  end
  
end