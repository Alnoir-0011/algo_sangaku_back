class DigestExistingApiKeyAccessTokens < ActiveRecord::Migration[8.1]
  class MigrationApiKey < ActiveRecord::Base
    self.table_name = "api_keys"
  end

  def up
    MigrationApiKey.reset_column_information

    # 誤って再実行された場合に、既にダイジェスト化済みの値を二重ハッシュ化しないよう、
    # SHA256 ダイジェスト形式（64文字の16進数）でない値のみを対象にする
    MigrationApiKey.where.not("access_token ~ ?", "^[0-9a-f]{64}$").find_each do |api_key|
      api_key.update_column(:access_token, Digest::SHA256.hexdigest(api_key.access_token))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
