require 'date'
module RruleHelper
  class Time
    #Returns a ISO 8601 complete formatted string of the time
    def complete
      self.utc.strftime("%Y%m%dT%H%M%SZ")
    end

    def self.parse_complete(value)

      #Time.xmlschema(value)
      d, h = value.split("T")
      if (h == nil)
        return Time.parse(d)
      else
        if h["Z"]
          #FIXME timezone!
          return Time.parse(d+" "+h.gsub("Z","")) + Time.now.utc_offset
        else
          return Time.parse(value)
        end
      end
    end
  end
  
  class Recurrence
    NONE_FREQUENCY = "NONE"   #add this to represent "no repeat", won't store actually
    DAILY_FREQUENCY = "DAILY"
    WEEKLY_FREQUENCY = "WEEKLY"

    FREQUENCIES = [DAILY_FREQUENCY, WEEKLY_FREQUENCY, NONE_FREQUENCY]

    WEEK = ["SU", "MO", "TU", "WE", "TH", "FR", "ST"]
    WEEK_REVERSE = {"SU" => 0, "MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4, "FR" => 5, "ST" => 6}
    
    attr_accessor :interval, :frequency, :count, :repeat_until, :day

    def interval
      @interval || 1
    end

    def interval=(i)
      i = i.to_i
      @interval = i if i > 0
    end
    
    def frequency
      @frequency || NONE_FREQUENCY
    end
    
    def frequency=(f)
      @frequency = f if f.is_a?(String) && FREQUENCIES.include?(f)
    end
    
    def count=(c)
      c = c.to_i
      if c > 0
        @count = c
        remove_instance_variable(:@repeat_until) if instance_variable_defined?(:@repeat_until)
      end
    end

    def repeat_until=(r)
      if r.is_a?(Date)
        @repeat_until = r.to_time.localtime + (24 * 60 * 60 - 1) #1s before the next day
      elsif r.is_a?(Time)
        @repeat_until = r
      end
      if !@repeat_until.nil?
        remove_instance_variable(:@count) if instance_variable_defined?(:@count)
      end      
    end

    def day
      ret = []
      for d in 0..6
        ret << d if @day[d]
      end
      ret
    end
    
    def day=(days)
      @day = Array.new(7, false)
      for d in days
        @day[d.to_i % 7] = true unless d.blank?
      end
    end

    def to_s
      return '' if frequency == NONE_FREQUENCY

      output = ''
      output += "RRULE:FREQ=#{@frequency}"
      output += ";COUNT=#{@count}" unless @count.nil?
      output += ";INTERVAL=#{@interval}" if self.interval > 1

      #TODO: BYMONTHDAY
      if @day && @day.include?(true)
        output += ";BYDAY="
        t = false
        for i in 0 .. 6
          if @day[i]
            output += "," if t
            output += WEEK[i]
            t = true
          end
        end
      end
      if @repeat_until
        if @all_day
          output += ";UNTIL=#{@repeat_until.strftime("%Y%m%d")}"
        else
          output += ";UNTIL=#{@repeat_until.complete}"
        end
      end
      output
    end

    def load(value)
      value.sub(/^RRULE:/,'').split(";").each do |rr|
        rr_key, rr_value = rr.split("=")
        if rr_key == 'FREQ'
          @frequency = rr_value
        elsif rr_key == 'INTERVAL'
          @interval = rr_value.to_i
        elsif rr_key == 'COUNT'
          @count = rr_value.to_i
        elsif rr_key == 'UNTIL'
          @repeat_until = Time.parse_complete(rr_value)
        elsif rr_key == 'BYDAY'
          @day = []
          rr_value.split(",").each do |d|
            @day[WEEK_REVERSE[d.upcase]] = true;
          end
        end
      end
    end

  end
end