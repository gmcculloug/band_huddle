require_relative '../spec_helper'

RSpec.describe SongVote do
  let(:band) { create(:band) }
  let(:song) { create(:song) }

  describe 'validations' do
    it 'requires an ip_address' do
      vote = SongVote.new(song: song, band: band)

      expect(vote).not_to be_valid
      expect(vote.errors[:ip_address]).to be_present
    end
  end

  describe '.rate_limited?' do
    it 'is false when there is no prior vote from that ip for that song/band' do
      expect(SongVote.rate_limited?('1.2.3.4', song, band)).to be false
    end

    it 'is true once that ip has voted for that song/band within the window' do
      SongVote.create!(song: song, band: band, ip_address: '1.2.3.4')

      expect(SongVote.rate_limited?('1.2.3.4', song, band)).to be true
    end

    it 'is false once the window has passed' do
      SongVote.create!(song: song, band: band, ip_address: '1.2.3.4', created_at: 2.days.ago)

      expect(SongVote.rate_limited?('1.2.3.4', song, band, window: 1.day)).to be false
    end

    it 'does not rate-limit a different song for the same ip' do
      other_song = create(:song)
      SongVote.create!(song: song, band: band, ip_address: '1.2.3.4')

      expect(SongVote.rate_limited?('1.2.3.4', other_song, band)).to be false
    end

    it 'does not rate-limit a different band for the same song and ip' do
      other_band = create(:band)
      SongVote.create!(song: song, band: band, ip_address: '1.2.3.4')

      expect(SongVote.rate_limited?('1.2.3.4', song, other_band)).to be false
    end
  end

  describe '.voted_today?' do
    it 'is true once that ip has voted for that song/band today' do
      SongVote.create!(song: song, band: band, ip_address: '1.2.3.4')

      expect(SongVote.voted_today?('1.2.3.4', song, band)).to be true
    end

    it 'is false when there is no vote' do
      expect(SongVote.voted_today?('1.2.3.4', song, band)).to be false
    end
  end

  describe '.retract!' do
    it "deletes that ip's vote(s) for the song/band" do
      SongVote.create!(song: song, band: band, ip_address: '1.2.3.4')

      SongVote.retract!('1.2.3.4', song, band)

      expect(SongVote.exists?(song: song, band: band, ip_address: '1.2.3.4')).to be false
    end

    it 'does not delete a different ip\'s vote' do
      SongVote.create!(song: song, band: band, ip_address: '5.6.7.8')

      SongVote.retract!('1.2.3.4', song, band)

      expect(SongVote.exists?(song: song, band: band, ip_address: '5.6.7.8')).to be true
    end
  end
end
