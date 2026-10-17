require_relative '../spec_helper'

RSpec.describe OauthService do
  describe '.find_existing_oauth_user' do
    let!(:linked_user) do
      create(:user).tap do |user|
        user.update!(oauth_provider: 'github', oauth_uid: '12345')
      end
    end

    it 'returns the user when provider and uid match' do
      user_info = { 'id' => '12345', 'email' => 'anything@example.com' }

      expect(described_class.find_existing_oauth_user('github', user_info)).to eq(linked_user)
    end

    it 'never matches by email alone' do
      user_info = { 'id' => '99999', 'email' => linked_user.email, 'email_verified' => true }

      expect(described_class.find_existing_oauth_user('github', user_info)).to be_nil
    end
  end

  describe '.find_link_candidate_by_email' do
    let!(:local_user) { create(:user, email: 'existing@example.com') }

    def candidate_for(user_info)
      described_class.find_link_candidate_by_email('github', user_info)
    end

    it 'returns the local user when the provider verified the email' do
      user_info = { 'id' => '99999', 'email' => 'existing@example.com', 'email_verified' => true }

      expect(candidate_for(user_info)).to eq(local_user)
    end

    it 'returns nil when the provider has not verified the email' do
      user_info = { 'id' => '99999', 'email' => 'existing@example.com', 'email_verified' => false }

      expect(candidate_for(user_info)).to be_nil
    end

    it 'returns nil when the verified claim is missing' do
      user_info = { 'id' => '99999', 'email' => 'existing@example.com' }

      expect(candidate_for(user_info)).to be_nil
    end

    it 'returns nil when user info has no email' do
      expect(candidate_for({ 'id' => '99999', 'email_verified' => true })).to be_nil
    end

    it 'returns nil when the email matches no user' do
      user_info = { 'id' => '99999', 'email' => 'nobody@example.com', 'email_verified' => true }

      expect(candidate_for(user_info)).to be_nil
    end

    it 'returns nil when the account already has an OAuth provider' do
      local_user.update!(oauth_provider: 'google', oauth_uid: 'aaa')
      user_info = { 'id' => '99999', 'email' => 'existing@example.com', 'email_verified' => true }

      expect(candidate_for(user_info)).to be_nil
    end
  end

  describe '.link_oauth_to_user' do
    let!(:user) { create(:user, email: 'link@example.com') }
    let(:user_info) { { 'id' => '99999', 'email' => 'link@example.com', 'username' => 'ghuser' } }

    it 'links the OAuth identity to the user' do
      described_class.link_oauth_to_user(user, 'github', user_info)

      expect(user.reload.oauth_provider).to eq('github')
      expect(user.reload.oauth_uid).to eq('99999')
      expect(user.reload.oauth_email).to eq('link@example.com')
    end

    it 'refuses to link when the user already has an OAuth provider' do
      user.update!(oauth_provider: 'google', oauth_uid: 'aaa')

      expect {
        described_class.link_oauth_to_user(user, 'github', user_info)
      }.to raise_error(/already has google OAuth account/)

      expect(user.reload.oauth_uid).to eq('aaa')
    end
  end

  describe '.normalize_user_info email_verified plumbing' do
    it 'maps the Google verified_email claim' do
      raw = { 'id' => '1', 'email' => 'a@example.com', 'verified_email' => true }
      normalized = described_class.send(:normalize_user_info, 'google', raw)

      expect(normalized['email_verified']).to be(true)
    end

    it 'treats a Google unverified email as unverified' do
      raw = { 'id' => '1', 'email' => 'a@example.com', 'verified_email' => false }
      normalized = described_class.send(:normalize_user_info, 'google', raw)

      expect(normalized['email_verified']).to be(false)
    end

    it 'maps the GitHub flag set from the /user/emails endpoint' do
      raw = { 'id' => 1, 'login' => 'gh', 'email' => 'a@example.com', 'email_verified' => true }
      normalized = described_class.send(:normalize_user_info, 'github', raw)

      expect(normalized['email_verified']).to be(true)
    end

    it 'maps the Apple email_verified string claim' do
      raw = { 'sub' => '1', 'email' => 'a@example.com', 'email_verified' => 'true' }
      normalized = described_class.send(:normalize_user_info, 'apple', raw)

      expect(normalized['email_verified']).to be(true)
    end

    it 'treats an Apple false string claim as unverified' do
      raw = { 'sub' => '1', 'email' => 'a@example.com', 'email_verified' => 'false' }
      normalized = described_class.send(:normalize_user_info, 'apple', raw)

      expect(normalized['email_verified']).to be(false)
    end
  end

  describe '.select_verified_github_email' do
    it 'prefers the primary verified email' do
      emails = [
        { 'email' => 'secondary@example.com', 'primary' => false, 'verified' => true },
        { 'email' => 'primary@example.com', 'primary' => true, 'verified' => true }
      ]

      expect(described_class.send(:select_verified_github_email, emails)).to eq('primary@example.com')
    end

    it 'falls back to a non-primary verified email' do
      emails = [
        { 'email' => 'unverified@example.com', 'primary' => true, 'verified' => false },
        { 'email' => 'secondary@example.com', 'primary' => false, 'verified' => true }
      ]

      expect(described_class.send(:select_verified_github_email, emails)).to eq('secondary@example.com')
    end

    it 'returns nil when no email is verified' do
      emails = [{ 'email' => 'unverified@example.com', 'primary' => true, 'verified' => false }]

      expect(described_class.send(:select_verified_github_email, emails)).to be_nil
    end

    it 'returns nil for malformed responses' do
      expect(described_class.send(:select_verified_github_email, 'error')).to be_nil
      expect(described_class.send(:select_verified_github_email, [])).to be_nil
    end
  end
end
