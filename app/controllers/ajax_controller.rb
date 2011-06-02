class AjaxController < ApplicationController
  layout :get_layout

  def get_layout
    nil
  end

  def load_news
  end

  def load_recent_events
  end

  def load_check_list
    event_id = params[:event_id]
    start_from = params[:start_from]
    offset = params[:offset].to_i
    @limit = params[:batchSize].to_i
    @checks = News.all(:conditions => ["target_event_id=? AND id<=? AND action=?", event_id, start_from, News::ACTION_CHECK], :limit => @limit, :offset => offset, :order => 'created_at DESC')
  end

end
