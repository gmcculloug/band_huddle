# Debug logging for the OAuth flow. Kept out of the test run so rspec output
# stays readable; set OAUTH_DEBUG=false to silence it in any environment.
module OauthDebugLog
  def self.log(message)
    return unless enabled?
    puts message
  end

  def self.enabled?
    return false if ENV['RACK_ENV'] == 'test'
    ENV['OAUTH_DEBUG'] != 'false'
  end
end
