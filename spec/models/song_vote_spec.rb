require_relative '../spec_helper'

RSpec.describe SongVote do
  let(:band) { create(:band) }
  let(:song) { create(:song) }
  let(:device_id) { 'device-1' }

  def create_vote(device_id: 'device-1', song: self.song, band: self.band, created_at: Time.current)
    SongVote.create!(
      song: song,
      band: band,
      ip_address: '1.2.3.4',
      device_id: device_id,
      created_at: created_at
    )
  end

  describe 'validations' do
    it 'requires an ip_address' do
      vote = SongVote.new(song: song, band: band, device_id: device_id)

      expect(vote).not_to be_valid
      expect(vote.errors[:ip_address]).to be_present
    end

    it 'requires a device_id' do
      vote = SongVote.new(song: song, band: band, ip_address: '1.2.3.4')

      expect(vote).not_to be_valid
      expect(vote.errors[:device_id]).to be_present
    end
  end

  describe '.rate_limited?' do
    it 'is false when the device has no prior vote for that song/band' do
      expect(SongVote.rate_limited?(device_id, song, band)).to be false
    end

    it 'is true once the device has voted for that song/band within the window' do
      create_vote

      expect(SongVote.rate_limited?(device_id, song, band)).to be true
    end

    it 'is false once the window has passed' do
      create_vote(created_at: 2.days.ago)

      expect(SongVote.rate_limited?(device_id, song, band, window: 1.day)).to be false
    end

    it 'does not rate-limit a different device on the same IP' do
      create_vote

      expect(SongVote.rate_limited?('device-2', song, band)).to be false
    end

    it 'does not rate-limit a different song for the same device' do
      other_song = create(:song)
      create_vote

      expect(SongVote.rate_limited?(device_id, other_song, band)).to be false
    end

    it 'does not rate-limit a different band for the same song and device' do
      other_band = create(:band)
      create_vote

      expect(SongVote.rate_limited?(device_id, song, other_band)).to be false
    end
  end

  describe '.voted_today?' do
    it 'is true once the device has voted for the song/band today' do
      create_vote

      expect(SongVote.voted_today?(device_id, song, band)).to be true
    end

    it 'is false when there is no vote' do
      expect(SongVote.voted_today?(device_id, song, band)).to be false
    end
  end

  describe '.retract!' do
    it "deletes that device's vote(s) for the song/band" do
      create_vote

      SongVote.retract!(device_id, song, band)

      expect(SongVote.exists?(song: song, band: band, device_id: device_id)).to be false
    end

    it 'does not delete a different device\'s vote' do
      create_vote(device_id: 'device-2')

      SongVote.retract!(device_id, song, band)

      expect(SongVote.exists?(song: song, band: band, device_id: 'device-2')).to be true
    end
  end
end
