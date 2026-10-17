require_relative '../spec_helper'

RSpec.describe SongRecommendation do
  let(:band) { create(:band) }

  def create_recommendation(device_id:, ip_address: '1.2.3.4', band: self.band)
    create(
      :song_recommendation,
      band: band,
      device_id: device_id,
      ip_address: ip_address
    )
  end

  describe '.rate_limited_for_device_or_ip?' do
    it 'rate-limits a forged device when the IP reached the limit' do
      5.times { |index| create_recommendation(device_id: "device-#{index}") }

      expect(SongRecommendation.rate_limited_for_device_or_ip?('forged-device', '1.2.3.4')).to be true
    end

    it 'does not rate-limit an unrelated device and IP' do
      5.times { |index| create_recommendation(device_id: "device-#{index}") }

      expect(SongRecommendation.rate_limited_for_device_or_ip?('new-device', '5.6.7.8')).to be false
    end
  end

  describe '.band_rate_limited?' do
    it 'rate-limits a band after aggregate submissions reach the limit' do
      create_recommendation(device_id: 'device-0')

      expect(SongRecommendation.band_rate_limited?(band, max: 2)).to be false

      create_recommendation(device_id: 'device-2')

      expect(SongRecommendation.band_rate_limited?(band, max: 2)).to be true
    end
  end
end
