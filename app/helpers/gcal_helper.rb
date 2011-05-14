module GcalHelper
  def create_calendar(name = 'TongShare', token = current_user.google.client, where = 'Beijing', timezone = 'Asia/Shanghai')
    service = GCal4Ruby::Service.new({:debug => true})
    service.authenticate(:access_token => token)
    cals = GCal4Ruby::Calendar.find(service, {:title => name})
    if cals.size  == 0
      cal = GCal4Ruby::Calendar.new(service, 
        {:title => name,
         :timezone => timezone,
         :where => where, 
         :summary => ''
        })
      cal.save
      Rails.logger.debug "Calendar #{name} created."
    else
      cal = cals.first
      Rails.logger.debug "Calendar #{name} exists."
    end
    cal
  end
  def create_event(event, token = current_user.google.client)
    
  end 
end
