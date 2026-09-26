require_relative '../spec_helper'

RSpec.describe SongBand do
  let(:band) { create(:band) }
  let(:song) { create(:song) }

  describe '.record_vote!' do
    it 'creates a songs_bands row with a vote count of 1 on first vote' do
      SongBand.record_vote!(song, band)

      song_band = SongBand.find_by_song_and_band(song, band)
      expect(song_band.votes_count).to eq(1)
      expect(song_band.votes_date).to eq(Time.now.utc.to_date)
    end

    it 'increments the count on a second vote the same day' do
      SongBand.record_vote!(song, band)
      SongBand.record_vote!(song, band)

      song_band = SongBand.find_by_song_and_band(song, band)
      expect(song_band.votes_count).to eq(2)
      expect(song_band.total_votes_count).to eq(2)
    end

    it 'resets the count to 1 when the last vote was on a previous day' do
      SongBand.record_vote!(song, band)
      SongBand.where(song_id: song.id, band_id: band.id)
        .update_all(votes_date: 1.day.ago.to_date)

      SongBand.record_vote!(song, band)

      song_band = SongBand.find_by_song_and_band(song, band)
      expect(song_band.votes_count).to eq(1)
      expect(song_band.votes_date).to eq(Time.now.utc.to_date)
    end

    it 'keeps vote counts independent per band for the same song' do
      other_band = create(:band)
      SongBand.record_vote!(song, band)

      other_song_band = SongBand.find_by_song_and_band(song, other_band)
      expect(other_song_band).to be_nil
    end

    it 'increments the all-time total on every vote, even across days' do
      SongBand.record_vote!(song, band)
      SongBand.where(song_id: song.id, band_id: band.id)
        .update_all(votes_date: 1.day.ago.to_date)

      SongBand.record_vote!(song, band)

      song_band = SongBand.find_by_song_and_band(song, band)
      expect(song_band.total_votes_count).to eq(2)
      expect(song_band.votes_count).to eq(1)
    end
  end

  describe '.retract_vote!' do
    it 'decrements a same-day vote count' do
      SongBand.record_vote!(song, band)
      SongBand.record_vote!(song, band)

      SongBand.retract_vote!(song, band)

      expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(1)
    end

    it 'does not go below zero' do
      SongBand.record_vote!(song, band)

      SongBand.retract_vote!(song, band)
      SongBand.retract_vote!(song, band)

      expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(0)
    end

    it 'leaves the stale daily count untouched but still decrements the all-time total' do
      SongBand.record_vote!(song, band)
      SongBand.where(song_id: song.id, band_id: band.id)
        .update_all(votes_date: 1.day.ago.to_date)

      SongBand.retract_vote!(song, band)

      song_band = SongBand.find_by_song_and_band(song, band)
      expect(song_band.votes_count).to eq(1)
      expect(song_band.total_votes_count).to eq(0)
    end

    it 'decrements the all-time total alongside a same-day retraction' do
      SongBand.record_vote!(song, band)
      SongBand.record_vote!(song, band)

      SongBand.retract_vote!(song, band)

      expect(SongBand.find_by_song_and_band(song, band).total_votes_count).to eq(1)
    end

    it 'does not let the all-time total go below zero' do
      SongBand.record_vote!(song, band)

      SongBand.retract_vote!(song, band)
      SongBand.retract_vote!(song, band)

      expect(SongBand.find_by_song_and_band(song, band).total_votes_count).to eq(0)
    end

    it 'is a no-op when there is no songs_bands row yet' do
      expect { SongBand.retract_vote!(song, band) }.not_to raise_error
    end
  end

  describe 'votes_count select via VOTES_COUNT_SQL' do
    it 'reports 0 for a stale (previous-day) vote count' do
      SongBand.record_vote!(song, band)
      SongBand.where(song_id: song.id, band_id: band.id)
        .update_all(votes_date: 1.day.ago.to_date)

      result = SongBand.where(song_id: song.id, band_id: band.id)
        .select("#{SongBand::VOTES_COUNT_SQL} AS votes_count").take

      expect(result.votes_count.to_i).to eq(0)
    end

    it "reports today's count when votes_date is today" do
      SongBand.record_vote!(song, band)

      result = SongBand.where(song_id: song.id, band_id: band.id)
        .select("#{SongBand::VOTES_COUNT_SQL} AS votes_count").take

      expect(result.votes_count.to_i).to eq(1)
    end
  end
end
