require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'initialization' do
    it 'access_token が自動で設定される' do
      api_key = ApiKey.new
      expect(api_key.access_token).to be_present
    end

    it 'expires_at がログインから7日後に設定される' do
      travel_to(Time.current) do
        api_key = ApiKey.new
        expect(api_key.expires_at).to eq(1.week.from_now)
      end
    end

    it 'access_token が SHA256 ダイジェスト形式（64文字の16進数文字列）で保存される' do
      # RED: set_defaults が access_token に生の SecureRandom.uuid をそのまま保存しているため、
      # ダイジェスト化されていない現状の実装では 64文字16進数の形式にならず失敗する
      api_key = ApiKey.new
      expect(api_key.access_token).to match(/\A[0-9a-f]{64}\z/)
    end

    it 'raw_token から生トークン（平文）が取得できる' do
      # RED: raw_token 属性が未実装のため NoMethodError で失敗する
      api_key = ApiKey.new
      expect(api_key.raw_token).to be_present
    end

    it 'raw_token は access_token とは異なる値である' do
      # RED: 現状の実装では access_token に raw_token 相当の値がそのまま保存されており、
      # ダイジェスト化されていないため raw_token と access_token が一致してしまい失敗する
      api_key = ApiKey.new
      expect(api_key.raw_token).not_to eq(api_key.access_token)
    end

    it 'ApiKey.digest(raw_token) が access_token の値と一致する' do
      # RED: ApiKey.digest クラスメソッドが未実装のため NoMethodError で失敗する
      api_key = ApiKey.new
      expect(ApiKey.digest(api_key.raw_token)).to eq(api_key.access_token)
    end

    it '生成のたびに異なる raw_token が生成される' do
      # RED: raw_token 属性が未実装のため NoMethodError で失敗する
      first_key = ApiKey.new
      second_key = ApiKey.new
      expect(first_key.raw_token).not_to eq(second_key.raw_token)
    end
  end

  describe '.digest' do
    it '同じ入力値に対して常に同じダイジェスト値を返す' do
      # RED: ApiKey.digest クラスメソッドが未実装のため NoMethodError で失敗する
      raw_token = SecureRandom.uuid
      expect(ApiKey.digest(raw_token)).to eq(ApiKey.digest(raw_token))
    end

    it 'Digest::SHA256.hexdigest によるダイジェスト値を返す' do
      # RED: ApiKey.digest クラスメソッドが未実装のため NoMethodError で失敗する
      raw_token = SecureRandom.uuid
      expect(ApiKey.digest(raw_token)).to eq(Digest::SHA256.hexdigest(raw_token))
    end
  end

  describe '.active scope' do
    let!(:active_key) { create(:api_key) }
    let!(:expired_key) { create(:api_key, :expired) }

    it '有効期限内の ApiKey のみ返す' do
      expect(ApiKey.active).to include(active_key)
      expect(ApiKey.active).not_to include(expired_key)
    end
  end
end
