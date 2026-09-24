# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # 並べ替え問題の正解順と、それを含む解答をログに残さない（issue #278）。
  # code_blocks は front が正解順に並べて送るため、配列の順序そのものが正解順になる。
  :correct_position, :block_ids, :code_blocks
]
