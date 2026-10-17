require 'securerandom'

module BandHuddle
  class SecurityHeaders
    NONCE_ENV_KEY = 'band_huddle.csp_nonce'
    STATIC_ASSET_EXTENSIONS = %w[.css .js .ico .png .jpg .jpeg .gif .svg .woff .woff2 .ttf .eot].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      env[NONCE_ENV_KEY] = SecureRandom.base64(24)
      status, headers, body = @app.call(env)

      apply_security_headers(headers, env)
      apply_cache_policy(headers, env) unless static_asset?(env)

      [status, headers, body]
    end

    private

    def apply_security_headers(headers, env)
      headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=(), payment=(), usb=()'
      headers['Cross-Origin-Opener-Policy'] = 'same-origin'
      headers['Cross-Origin-Embedder-Policy'] = 'require-corp'
      headers['Content-Security-Policy'] = content_security_policy(env[NONCE_ENV_KEY]) if html_response?(headers)
    end

    def apply_cache_policy(headers, env)
      return unless authenticated_response?(env, headers) || html_response?(headers) || json_response?(headers)

      headers['Cache-Control'] = 'no-store, private'
      headers['Pragma'] = 'no-cache'
      headers['Expires'] = '0'
    end

    def content_security_policy(nonce)
      [
        "default-src 'self'",
        "base-uri 'self'",
        "object-src 'none'",
        "frame-ancestors 'none'",
        "form-action 'self'",
        "script-src-elem 'self' 'nonce-#{nonce}'",
        "script-src-attr 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data:",
        "font-src 'self'",
        "connect-src 'self'",
        "manifest-src 'self'",
        "worker-src 'self'"
      ].join('; ')
    end

    def authenticated_response?(env, headers)
      env.key?('HTTP_AUTHORIZATION') || env['rack.session'].key?('user_id') || headers['WWW-Authenticate']
    end

    def html_response?(headers)
      headers['Content-Type'].to_s.include?('text/html')
    end

    def json_response?(headers)
      headers['Content-Type'].to_s.include?('application/json')
    end

    def static_asset?(env)
      path = env['PATH_INFO'].to_s
      STATIC_ASSET_EXTENSIONS.any? { |extension| path.end_with?(extension) }
    end
  end
end
