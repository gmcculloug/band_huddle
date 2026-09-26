require 'rack'
require 'securerandom'

module BandHuddle
  class DeviceId
    COOKIE_NAME = 'band_huddle_device_id'.freeze
    ENV_KEY = 'band_huddle.device_id'.freeze
    COOKIE_MAX_AGE = 365 * 24 * 60 * 60
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      device_id = request.cookies[COOKIE_NAME]
      new_device_id = !device_id&.match?(UUID_PATTERN)
      device_id = SecureRandom.uuid if new_device_id
      env[ENV_KEY] = device_id

      status, headers, body = @app.call(env)
      if new_device_id
        secure = production? || env['HTTPS'] == 'on' || env['HTTP_X_FORWARDED_PROTO'] == 'https'
        Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, {
          value: device_id,
          path: '/',
          max_age: COOKIE_MAX_AGE,
          httponly: true,
          secure: secure,
          same_site: :lax
        })
      end

      [status, headers, body]
    end

    private

    def production?
      ENV['RACK_ENV'] == 'production' || ENV['APP_ENV'] == 'production'
    end
  end
end
