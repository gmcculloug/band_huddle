require 'rack/protection'

module BandHuddle
  class BrowserCsrfProtection
    SAFE_REQUEST_METHODS = %w[GET HEAD OPTIONS TRACE].freeze
    CSRF_EXEMPT_PATH_PREFIXES = %w[/api/auth/ /api/mobile/].freeze

    def initialize(app)
      @app = app
      @authenticity_token = Rack::Protection::AuthenticityToken.new(app)
    end

    def call(env)
      return @app.call(env) if safe_request?(env) || csrf_exempt?(env)

      @authenticity_token.call(env)
    end

    private

    def safe_request?(env)
      SAFE_REQUEST_METHODS.include?(env['REQUEST_METHOD'])
    end

    def csrf_exempt?(env)
      path = env['PATH_INFO'].to_s
      CSRF_EXEMPT_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end
  end
end
