module HttpUrlValidation
  extend ActiveSupport::Concern

  included do
    validate :validate_http_urls
  end

  private

  def validate_http_urls
    self.class.http_url_fields.each do |field|
      value = public_send(field)
      next if value.blank?

      parsed_url = URI.parse(value)
      next if %w[http https].include?(parsed_url.scheme&.downcase) && parsed_url.host.present?

      errors.add(field, 'must be a valid http:// or https:// URL')
    rescue URI::InvalidURIError
      errors.add(field, 'must be a valid http:// or https:// URL')
    end
  end

  class_methods do
    def validates_http_url(*fields)
      @http_url_fields = fields.freeze
    end

    def http_url_fields
      @http_url_fields || []
    end
  end
end
