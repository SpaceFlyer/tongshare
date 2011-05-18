class PrivateController < ApplicationController
  include EventsHelper
  before_filter :authenticate_user!

  def get_diff
    user = current_user
    if (params[:last_update])
      last_update = Time.parse(params[:last_update]).utc
    else
      last_update = 0
    end

    instances = query_diff_accepted_instance_includes_event(last_update, user.id)
    result = {:time_now => Time.now.localtime, :instances => instances, :events => instances.map{ |i| i.event }}
    respond_to do |format|
      format.html { render :text => result.to_json }
      format.json { render :json => result }
      if (params[:disable_escape] && params[:disable_escape] == 'true')
        format.xml do
          coder = coder = HTMLEntities.new
          xml_result = result.to_xml
          xml_result.gsub!(/&#\d+;/) { |m| coder.decode(m)}
          render :text => xml_result
        end
      else
        format.xml { render :xml => result }
      end
    end
  end

end
