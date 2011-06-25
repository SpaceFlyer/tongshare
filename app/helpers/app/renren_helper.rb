require 'digest/md5'
module App::RenrenHelper
  RENREN_SITE = 'https://graph.renren.com'
  RENREN_ACCESS_TOKEN_URL = '/oauth/token'
  API_URL = 'http://api.renren.com/restserver.do'
  RENREN_FIX = 'renren.com'
  
  def api_call(access_token, method, params = {})
    params = params.merge({
      'access_token' => access_token.token,
      'call_id' => Time.now.to_i.to_s, 
#     'field' => 'name,tinyurl', 
      'format' => 'JSON',
      'method' => method, 
      'v' => '1.0'
    })
    url = URI.parse(API_URL)
    resp, data = Net::HTTP.post_form(url, params.merge({'sig' => sig(params)}))
    data
  end
  
  def sig(params)
    s = ''
    a = params.to_a.sort
    a.each do |p|
      s = s + p[0].to_s + '=' + p[1].to_s
    end
    s = s + RENREN_APP_SECRET
    md5 = Digest::MD5.new
    md5.update(s)
    md5.hexdigest
  end
end
