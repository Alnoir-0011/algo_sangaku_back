# 第三者が投稿した任意の Ruby コードを実行する Lambda ハンドラ。
#
# Ruby には権限モデルが存在しない（$SAFE は 3.0 で通常のグローバル変数に降格、taint は 3.2 で
# 削除、default gem の fiddle から libc の任意関数を直接呼べる）。したがって Ruby レベルの
# サンドボックスは成立せず、唯一意味のある境界は OS プロセス境界である。
#
# ここでは「ハンドラ（信頼）≠ ユーザーコード（非信頼）」をプロセスで分離し、rlimit と SIGKILL、
# 実行後の掃除で封じ込める。設計の根拠と「防げないもの」は ../README.md を参照。

require "fiddle"
require "fileutils"
require "json"
require "rbconfig"
require "securerandom"

module CodeRunner
  # --- 子プロセスのリソース上限 ---

  # ソフト 5s で SIGXCPU（捕捉可能）、ハード 6s でカーネルが SIGKILL。
  # ペアで指定することで trap("XCPU") {} による回避を無効化する。
  CPU_SECONDS = [ 5, 6 ].freeze
  # RLIMIT_AS は仮想アドレス空間の制限で、Ruby 3.4 は起動しただけで約 450MiB を予約する
  # （404MiB の匿名マッピング 1 本が大半。MALLOC_ARENA_MAX では減らない）。そのぶんを
  # 織り込まないと正当な解答まで NoMemoryError になるため、実測で決めた値を使う。
  #
  #   RLIMIT_AS  ユーザーコードが確保できた最大配列
  #     512MiB    50MiB   ← 設計時の想定値。狭すぎる
  #     768MiB   300MiB   ← 採用。競技プログラミングの標準的な 256MB 制限を満たせる
  #    1024MiB   500MiB
  #
  # 関数メモリ 1,769MB に対しては十分小さいので、メモリ爆弾では子だけが NoMemoryError で
  # 死に、実行環境は生き残って stderr を返せる。この上限を外すと実行環境ごと OOM する。
  ADDRESS_SPACE_BYTES = 768 * 1024 * 1024
  # 1 ファイルあたり。/tmp（512MB）を 1 ファイルで埋められないようにする。
  FILE_SIZE_BYTES = 8 * 1024 * 1024
  # Lambda 全体の fd 上限 1,024 を子 1 つで食わせない。
  OPEN_FILES = 64
  # core dump による /tmp 圧迫を防ぐ。
  CORE_SIZE = 0
  # RLIMIT_STACK は指定しない。下げると正当な深い再帰が SystemStackError になり採点結果が変わる。

  # RLIMIT_NPROC は per-UID かつ Linux ではスレッドも計上されるため、
  # Init 時に自 UID のタスク数を数えて余裕分を足す（fork bomb 対策）。
  #
  # 前回の invoke の残骸がゼロであることが前提の値である点に注意。残留プロセスがあると
  # そのぶん正当な提出が使えるタスク数が減るので、掃除の確実性がそのまま可用性に効く。
  NPROC_HEADROOM = 8
  # /proc が読めない環境（macOS 等）向けのフォールバック。
  NPROC_FALLBACK = 64

  # --- 入出力の制限 ---

  # パイプから読み取る際のバイト上限。ここで打ち切らないとハンドラ側のメモリを食い潰す。
  OUTPUT_LIMIT_BYTES = 64 * 1024
  # レスポンスに載せる文字数の上限。
  #
  # answer_results.output の Rails 側バリデーション（65,535 文字）を必ず下回らせる。
  # バイトで切っただけだと
  #   - ASCII 64KiB = 65,536 文字ちょうどで上限を 1 文字超える
  #   - 不正バイトの scrub で 1 バイトが U+FFFD（3 バイト）に膨らむ
  # のどちらでも保存に失敗し、CorrectnessCheckJob の retry で同じコードが 3 回実行される。
  RESPONSE_MAX_CHARS = 60_000
  # answers.source / fixed_inputs.content の Rails 側バリデーションと揃える。
  SOURCE_MAX_LENGTH = 65_535
  STDIN_MAX_LENGTH = 65_535

  DEFAULT_TIMEOUT_MS = 5_000
  MAX_TIMEOUT_MS = 5_000
  # SIGKILL 後に残りの出力を読み切りゾンビを回収するための猶予。
  # これを超えたら諦めて戻る（Lambda 関数タイムアウト 10s に食い込ませない）。
  KILL_GRACE_SECONDS = 1.0
  # cleanup でゾンビ回収に使う予算。ゾンビも RLIMIT_NPROC を消費するので取りこぼしたくないが、
  # ここで粘りすぎると関数タイムアウトに食い込む。
  REAP_TIMEOUT_SECONDS = 0.2
  POLL_INTERVAL_SECONDS = 0.05
  READ_CHUNK_BYTES = 64 * 1024

  ENTRYPOINT_FILENAME = "main.rb"
  STDIN_FILENAME = "stdin.txt"
  WORKDIR_PREFIX = "run-"

  # ユーザーコードに渡す環境変数はこれだけ（unsetenv_others: true で他は全て消える）。
  # PATH に ruby の実体（Lambda では /var/lang/bin）を含めていないので、
  # インタプリタは必ず RbConfig.ruby の絶対パスで起動すること。
  CHILD_PATH = "/usr/bin:/bin"
  CHILD_LANG = "C.UTF-8"
  CHILD_TZ = "Asia/Tokyo"

  # Lambda は実行環境を warm start で使い回し、/tmp はクラッシュによるリセット時ですら
  # 次の呼び出しに持ち越される。テストが本物の /tmp を消さずに済むよう差し替え可能にしている
  # （本番では常に /tmp）。
  TMP_ROOT = ENV.fetch("CODE_RUNNER_TMP_ROOT", "/tmp")

  # TMP_ROOT の全削除は破壊的なので、Lambda 実行環境か、TMP_ROOT が明示指定されている
  # ときだけ行う。この条件が無いと、開発機で誤って handler.rb を読み込んだだけで
  # 本物の /tmp が消える。
  # （AWS_LAMBDA_FUNCTION_NAME は本番の予約環境変数、LAMBDA_TASK_ROOT は RIE でも入る）
  TMP_ROOT_WIPABLE = ENV.key?("AWS_LAMBDA_FUNCTION_NAME") ||
                     ENV.key?("LAMBDA_TASK_ROOT") ||
                     ENV.key?("CODE_RUNNER_TMP_ROOT")

  # /proc 経由のプロセス観測。Linux 以外では機能しない。
  module ProcessTable
    PROC_ROOT = "/proc"
    # /proc/<pid>/stat の starttime は 22 番目のフィールド。comm（2 番目）を読み飛ばした
    # 配列では 3 番目のフィールドが先頭に来るので index は 22 - 3 = 19。
    STARTTIME_INDEX = 19

    module_function

    def available?
      File.directory?(PROC_ROOT)
    end

    def own_uid_pids
      return [] unless available?

      Dir.children(PROC_ROOT).filter_map do |entry|
        next unless entry.match?(/\A\d+\z/)

        pid = entry.to_i
        pid if owned_by_me?(pid)
      end
    rescue SystemCallError
      # cleanup の ensure から呼ばれるため、ここで例外を上げると本来伝搬すべき例外を潰す。
      []
    end

    def owned_by_me?(pid)
      File.stat(File.join(PROC_ROOT, pid.to_s)).uid == Process.uid
    rescue SystemCallError
      false
    end

    # RLIMIT_NPROC はプロセスではなくタスク（スレッド）を数えるので、
    # ここでも /proc/<pid>/task を数える。
    def own_uid_task_count
      own_uid_pids.sum { |pid| task_count(pid) }
    end

    def task_count(pid)
      Dir.children(File.join(PROC_ROOT, pid.to_s, "task")).size
    rescue SystemCallError
      0
    end

    # comm には空白や括弧が入りうるので、最後の閉じ括弧の後ろから分割する。
    def start_ticks(pid)
      stat = File.read(File.join(PROC_ROOT, pid.to_s, "stat"))
      close_paren = stat.rindex(")")
      return nil unless close_paren

      stat[(close_paren + 2)..].to_s.split[STARTTIME_INDEX]&.to_i
    rescue SystemCallError
      nil
    end
  end

  # ハンドラプロセスを ptrace 不可・/proc 非公開にする。
  #
  # 子とハンドラは同一 UID なので、既定では子がハンドラを PTRACE_ATTACH できる。これは
  # メモリの覗き見に留まらず、**PTRACE_ATTACH が対象に SIGSTOP を送る**ため、ハンドラを
  # 停止させて Lambda 関数タイムアウトまで実行環境を占有する DoS になる（実測で確認）。
  # dumpable を落とすと ptrace_may_access() が EPERM になり、同じ判定を通る
  # /proc/<ppid>/environ 経由の AWS 認証情報窃取もまとめて塞げる。
  #
  # 子は execve で dumpable=1 に戻るため、ユーザーコード側の挙動は変わらない。
  PR_SET_DUMPABLE = 4

  def self.protect_from_ptrace
    prctl = Fiddle::Function.new(
      Fiddle::Handle.new(nil)["prctl"],
      [ Fiddle::TYPE_INT ] * 5,
      Fiddle::TYPE_INT
    )
    prctl.call(PR_SET_DUMPABLE, 0, 0, 0, 0).zero?
  rescue StandardError
    # prctl を持たない環境（macOS 等）では諦める。本番は常に Linux。
    false
  end

  # TMP_ROOT 直下を空にする。
  #
  # Init 時にも invoke ごとにも呼ぶ。「ベースラインを採って差分だけ消す」方式にすると、
  # ユーザーコードが Process.kill("KILL", ppid) で cleanup を回避してファイルを残した場合、
  # 次の Init でその残骸がベースラインに昇格し、以後の掃除対象から永久に外れてしまう。
  #
  # 注意: /tmp を使う Lambda Extension を追加する場合はこの挙動を見直すこと。
  def self.wipe_tmp_root
    return unless TMP_ROOT_WIPABLE
    return unless File.directory?(TMP_ROOT)

    Dir.children(TMP_ROOT).each { |entry| FileUtils.rm_rf(File.join(TMP_ROOT, entry)) }
  rescue SystemCallError
    nil
  end

  # --- Init フェーズ（実行環境ごとに 1 度だけ評価される）---
  #
  # ここで凍結したベースラインを毎 invoke の後始末で使う。

  wipe_tmp_root

  BASELINE_PIDS = ProcessTable.own_uid_pids.freeze
  # 自分自身の /proc が読めないことは現実には起きないが、万一 nil になった場合は 0 に倒す。
  # sweep 側の条件は `ticks < HANDLER_START_TICKS` なので、0 なら誰も見逃さない（fail-close）。
  HANDLER_START_TICKS = ProcessTable.start_ticks(Process.pid) || 0
  NPROC_LIMIT = begin
    count = ProcessTable.own_uid_task_count
    count.positive? ? count + NPROC_HEADROOM : NPROC_FALLBACK
  end
  # ベースラインを採り終えてから保護をかける（順序を入れ替えても実測上は同じだが、
  # /proc の見え方に依存する処理を保護前に済ませておく方が安全側）。
  PTRACE_PROTECTED = protect_from_ptrace

  # 保護に失敗したまま黙って動き続けると、ptrace によるハンドラ停止と /proc 経由の
  # 認証情報窃取が復活する。fiddle は Ruby 4.0 で default gem から外れるため、
  # ランタイム更新でここが壊れうる。CloudWatch Logs に残して気づけるようにする。
  unless PTRACE_PROTECTED
    warn "[code_runner] prctl(PR_SET_DUMPABLE, 0) に失敗しました。" \
         "ptrace 保護と /proc 経由の情報漏洩対策が無効な状態で動作します。"
  end

  # 上限に達した後も読み捨てを続けるバッファ。
  # 読むのを止めるとパイプが満杯になって子がブロックし、kill 処理とデッドロックする。
  class CappedBuffer
    def initialize(limit_bytes:, max_chars:)
      @limit_bytes = limit_bytes
      @max_chars = max_chars
      @bytes = "".b
      @truncated = false
      @text = nil
    end

    def <<(chunk)
      remaining = @limit_bytes - @bytes.bytesize
      if remaining <= 0
        @truncated = true
      elsif chunk.bytesize > remaining
        @bytes << chunk.byteslice(0, remaining)
        @truncated = true
      else
        @bytes << chunk
      end
      self
    end

    # 読み切ったあとに 1 度だけ呼ぶ。text / truncated? はこれ以降に参照する。
    #
    # PostgreSQL の text 型に保存できる文字列にするため、この順序で処理する。
    #   1. 不正な UTF-8 を scrub する（1 バイトが U+FFFD = 3 バイトに膨らむ）
    #   2. NUL を落とす。valid_encoding? は true を返し scrub でも消えないが、
    #      PostgreSQL は符号位置 0 を保持できない
    #   3. 最後に文字数で締める。1 と 2 でバイト数も文字数も変わるので、締めは必ず最後
    def finalize
      text = @bytes.dup.force_encoding(Encoding::UTF_8)
      text = text.scrub unless text.valid_encoding?
      text = text.tr("\u0000", "\uFFFD") if text.include?("\u0000")

      if text.length > @max_chars
        text = text[0, @max_chars]
        @truncated = true
      end

      @text = text
      self
    end

    attr_reader :text

    def truncated?
      @truncated
    end
  end

  # 1 回の invoke。
  class Sandbox
    def call(event)
      started_at = monotonic_now
      raise ArgumentError, "event must be a Hash" unless event.is_a?(Hash)

      # 前回の invoke がハンドラごと殺されて cleanup を完走できていない場合に備え、
      # 開始時にも掃除する。これがないと残骸が今回のユーザーコードと同時に動き、
      # /tmp に残った main.rb や stdin.txt を読まれる。
      sweep_stray_processes
      CodeRunner.wipe_tmp_root

      source = fetch_source(event)
      stdin_text = fetch_stdin(event)
      timeout_seconds = fetch_timeout_seconds(event)

      @workdir = prepare_workdir(source, stdin_text)
      result = execute(timeout_seconds)

      build_response(result, event, started_at)
    ensure
      cleanup
    end

    private

    def fetch_source(event)
      source = event["source"]
      raise ArgumentError, "source must be a String" unless source.is_a?(String)
      raise ArgumentError, "source is too long" if source.length > SOURCE_MAX_LENGTH

      source
    end

    def fetch_stdin(event)
      stdin_text = event["stdin"] || ""
      raise ArgumentError, "stdin must be a String" unless stdin_text.is_a?(String)
      raise ArgumentError, "stdin is too long" if stdin_text.length > STDIN_MAX_LENGTH

      stdin_text
    end

    def fetch_timeout_seconds(event)
      requested = event["timeout_ms"]
      return DEFAULT_TIMEOUT_MS / 1000.0 if requested.nil?
      raise ArgumentError, "timeout_ms must be numeric" unless requested.is_a?(Numeric)

      requested = requested.to_i
      requested = DEFAULT_TIMEOUT_MS unless requested.positive?
      [ requested, MAX_TIMEOUT_MS ].min / 1000.0
    end

    def prepare_workdir(source, stdin_text)
      path = File.join(TMP_ROOT, "#{WORKDIR_PREFIX}#{SecureRandom.uuid}")
      # mkdir_p と違い、既に存在すれば失敗する。UUID なので衝突は事故だけだが、
      # 他人が先回りして作ったディレクトリを使うことがないようにしておく。
      Dir.mkdir(path, 0o700)
      write_exclusively(File.join(path, ENTRYPOINT_FILENAME), source)
      write_exclusively(File.join(path, STDIN_FILENAME), stdin_text)
      path
    end

    # O_EXCL | O_NOFOLLOW で開く。残留プロセスがいた場合に main.rb をシンボリックリンクへ
    # 差し替えて採点を乗っ取る、という経路を塞ぐ。
    def write_exclusively(path, content)
      flags = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW | File::BINARY
      File.open(path, flags, 0o600) { |file| file.write(content) }
    end

    def execute(timeout_seconds)
      ios = []

      begin
        out_reader, out_writer = IO.pipe
        ios.push(out_reader, out_writer)
        err_reader, err_writer = IO.pipe
        ios.push(err_reader, err_writer)

        begin
          @pgid = spawn_child(out_writer, err_writer)
        ensure
          # 親側の書き込み端を閉じないと子の終了後も EOF が来ない。
          close_io(out_writer)
          close_io(err_writer)
        end

        pump(out_reader, err_reader, timeout_seconds)
      ensure
        # 2 本目の IO.pipe が失敗した場合でも、開いた分は必ず閉じる。
        ios.each { |io| close_io(io) }
      end
    end

    def spawn_child(out_writer, err_writer)
      Process.spawn(
        child_env,
        RbConfig.ruby,
        "-E", "UTF-8:UTF-8",
        # -w は付けない。"assigned but unused variable" が stderr に出て採点に影響する。
        "--disable-did_you_mean",
        "--disable-error_highlight",
        ENTRYPOINT_FILENAME,
        unsetenv_others: true,
        # プロセスグループ宛 SIGKILL でツリーを一括終了するため。
        pgroup: true,
        chdir: @workdir,
        # fd 3 以降の継承を防ぎ、ハンドラが握るソケット等を子に渡さない。
        close_others: true,
        umask: 0o077,
        # stdin はパイプではなくファイル。パイプにすると子が読まない大入力で
        # 親の write がブロックしデッドロックする。
        in: File.join(@workdir, STDIN_FILENAME),
        out: out_writer,
        err: err_writer,
        **rlimits
      )
    end

    def child_env
      {
        "LANG" => CHILD_LANG,
        "TZ" => CHILD_TZ,
        "HOME" => @workdir,
        "PATH" => CHILD_PATH
      }
    end

    def rlimits
      {
        rlimit_cpu: CPU_SECONDS,
        rlimit_as: ADDRESS_SPACE_BYTES,
        rlimit_nproc: NPROC_LIMIT,
        rlimit_fsize: FILE_SIZE_BYTES,
        rlimit_nofile: OPEN_FILES,
        rlimit_core: CORE_SIZE
      }
    end

    # 出力の読み取りと壁時計デッドラインの監視を 1 つのループで行う。
    #
    # Ruby の Timeout を子プロセスの内部に仕込む方式は rescue Exception / ensure で
    # 握り潰せるため無効。ここで親がモノトニック時計を見て SIGKILL する。
    # SIGTERM は trap("TERM") {} で無視されるので一切送らない。
    def pump(out_reader, err_reader, timeout_seconds)
      buffers = { out_reader => new_buffer, err_reader => new_buffer }
      open_readers = buffers.keys.dup
      deadline = monotonic_now + timeout_seconds
      hard_deadline = nil
      status = nil
      timed_out = false

      loop do
        now = monotonic_now

        if !timed_out && now >= deadline
          timed_out = true
          hard_deadline = now + KILL_GRACE_SECONDS
          terminate_children
        end

        break if hard_deadline && now >= hard_deadline

        read_ready(open_readers, buffers)
        status ||= reap
        break if status && open_readers.empty?

        # 子は終わったが孫がパイプを握っている場合、EOF は来ない。
        # デッドラインまで待ち、超えたら kill してから読み切る。
        sleep(POLL_INTERVAL_SECONDS) if open_readers.empty? && status.nil?
      end

      status ||= reap
      {
        stdout: buffers[out_reader].finalize,
        stderr: buffers[err_reader].finalize,
        status: status,
        timed_out: timed_out
      }
    end

    def new_buffer
      CappedBuffer.new(limit_bytes: OUTPUT_LIMIT_BYTES, max_chars: RESPONSE_MAX_CHARS)
    end

    def read_ready(open_readers, buffers)
      return if open_readers.empty?

      ready = IO.select(open_readers, nil, nil, POLL_INTERVAL_SECONDS)
      return unless ready

      ready.first.each do |io|
        buffers[io] << io.read_nonblock(READ_CHUNK_BYTES)
      rescue IO::WaitReadable
        next
      rescue EOFError, IOError, SystemCallError
        open_readers.delete(io)
      end
    end

    def reap
      _, status = Process.waitpid2(@pgid, Process::WNOHANG)
      status
    rescue Errno::ECHILD
      # 既に回収済み。exit status は取得できない。
      nil
    end

    def terminate_children
      kill_process_group
      sweep_stray_processes
    end

    def kill_process_group
      return unless @pgid

      Process.kill("KILL", -@pgid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    # Process.setsid でプロセスグループから抜けた孫や、前回の invoke で取りこぼした
    # 残骸を回収する最終手段。
    #
    # 「Init 時のベースラインに無い PID」だけを条件にすると、Lambda 以外の環境
    # （CI ランナー等）で無関係なプロセスを巻き込みうる。ハンドラ自身の starttime 以降に
    # 生まれたものという条件を重ね、対象をこの実行環境が生んだ子孫に限定している。
    def sweep_stray_processes
      return unless ProcessTable.available?

      (ProcessTable.own_uid_pids - BASELINE_PIDS).each do |pid|
        next if pid == Process.pid

        ticks = ProcessTable.start_ticks(pid)
        # starttime が読めなかったものは見逃さず殺す（fail-close）。
        # ベースライン外と分かっている以上、取りこぼす方が危険。
        next if ticks && ticks < HANDLER_START_TICKS

        begin
          Process.kill("KILL", pid)
        rescue Errno::ESRCH, Errno::EPERM
          next
        end
      end
    end

    def build_response(result, event, started_at)
      status = result[:status]
      exited_normally = status && !status.signaled?
      {
        "stdout" => result[:stdout].text,
        "stderr" => result[:stderr].text,
        "exit_status" => exited_normally ? status.exitstatus : nil,
        "signal" => status&.signaled? ? Signal.signame(status.termsig) : nil,
        "timed_out" => result[:timed_out],
        "truncated" => {
          "stdout" => result[:stdout].truncated?,
          "stderr" => result[:stderr].truncated?
        },
        "duration_ms" => ((monotonic_now - started_at) * 1000).round,
        "request_token" => event["request_token"]
      }
    end

    # invoke ごとに必ず実行する後始末。
    # Lambda は完了しなかったバックグラウンドプロセスを実行環境の再利用時に再開させるため、
    # プロセスとファイルの両方を残さない。
    def cleanup
      kill_process_group
      sweep_stray_processes
      reap_remaining
      CodeRunner.wipe_tmp_root
    end

    # ゾンビも RLIMIT_NPROC を消費する。SIGKILL 直後は終了しきっていないことがあるので、
    # 短い予算のあいだ回収を試みる。
    def reap_remaining
      return unless @pgid

      deadline = monotonic_now + REAP_TIMEOUT_SECONDS
      loop do
        return if Process.waitpid(@pgid, Process::WNOHANG)
        return if monotonic_now >= deadline

        sleep(POLL_INTERVAL_SECONDS / 5)
      end
    rescue Errno::ECHILD
      nil
    end

    def close_io(io)
      io.close if io && !io.closed?
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

# Lambda ランタイムの呼び出し規約。context はこのハンドラでは使わないが引数として必須。
def lambda_handler(event:, context:)
  # VPC に接続した関数は 14 日アイドルすると Hyperplane ENI が回収され、Inactive になって
  # 次の呼び出しが失敗する。EventBridge Scheduler が 1 日 1 回 {"warmup": true} を投げて
  # これを防ぐ（terraform/lambda.tf の aws_scheduler_schedule.code_runner_warmup）。
  #
  # ここで返すのは Sandbox に入る前である点が重要。source を持たないウォームアップ用の
  # イベントを Sandbox に渡すと ArgumentError になるうえ、掃除や子プロセス起動といった
  # 実行経路を毎日通す必要もない。
  return { "warmup" => true } if event.is_a?(Hash) && event["warmup"]

  CodeRunner::Sandbox.new.call(event)
end
