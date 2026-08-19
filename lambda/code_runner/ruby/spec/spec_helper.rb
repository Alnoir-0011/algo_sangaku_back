require 'fiddle'
require 'fileutils'
require 'tempfile'
require 'tmpdir'

# ハンドラは Init フェーズで TMP_ROOT のベースラインを凍結し、invoke ごとにベースライン外の
# エントリを削除する。テスト実行環境の /tmp を巻き込まないよう、handler を読み込む前に
# テスト専用ディレクトリへ差し替える。
CODE_RUNNER_SPEC_TMP_ROOT = Dir.mktmpdir('code-runner-spec-')
ENV['CODE_RUNNER_TMP_ROOT'] = CODE_RUNNER_SPEC_TMP_ROOT
at_exit { FileUtils.remove_entry(CODE_RUNNER_SPEC_TMP_ROOT) if File.directory?(CODE_RUNNER_SPEC_TMP_ROOT) }

require_relative '../handler'

module SandboxHelpers
  def run_code(source, stdin: '', timeout_ms: 5_000, request_token: 'test-token')
    lambda_handler(
      event: {
        'source' => source,
        'stdin' => stdin,
        'timeout_ms' => timeout_ms,
        'request_token' => request_token
      },
      context: nil
    )
  end

  def tmp_root
    CodeRunner::TMP_ROOT
  end

  # SIGKILL 直後は親に回収されるまでゾンビとして /proc に残るため、state で判定する。
  def process_alive?(pid)
    stat = File.read("/proc/#{pid}/stat")
    stat[(stat.rindex(')') + 2)..].split.first != 'Z'
  rescue Errno::ENOENT
    false
  end
end

RSpec.configure do |config|
  config.include SandboxHelpers

  # rlimit_as は Linux 専用で、macOS では Process.spawn 自体が失敗する。
  config.filter_run_excluding(:linux) unless RUBY_PLATFORM.include?('linux')

  # RLIMIT_NPROC は per-UID の制限で、root では無視される。root で走らせても fork bomb 対策の
  # 検証にはならないため、黙って通すのではなくスキップして警告する。
  # 本番の Lambda も GitHub Actions のランナーも非 root なので、そこでは実行される
  # （act のようなローカルの CI エミュレータは root コンテナで動くのでスキップされる）。
  if Process.uid.zero?
    warn "\n[warn] root で実行しているため RLIMIT_NPROC の検証をスキップします。" \
         "fork bomb 対策を検証するには非 root で実行してください。\n\n"
    config.filter_run_excluding(:non_root)
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.order = :random
  Kernel.srand config.seed
end
