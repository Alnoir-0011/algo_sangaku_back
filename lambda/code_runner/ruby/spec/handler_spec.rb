RSpec.describe 'lambda_handler', :linux do
  describe 'normal execution' do
    it 'returns the stdout produced by the submitted source' do
      result = run_code('puts "hello"')

      expect(result['stdout']).to eq("hello\n")
      expect(result['stderr']).to eq('')
    end

    it 'feeds the given stdin to the submitted source' do
      result = run_code('puts gets.to_i * 2', stdin: "21\n")

      expect(result['stdout']).to eq("42\n")
    end

    it 'reports exit_status 0 and no signal when the source completes successfully' do
      result = run_code('puts "done"')

      expect(result['exit_status']).to eq 0
      expect(result['signal']).to be_nil
      expect(result['timed_out']).to be false
    end

    it 'reports the exit status chosen by the source' do
      result = run_code('exit 3')

      expect(result['exit_status']).to eq 3
    end

    it 'echoes back the request_token so the caller can match the response' do
      result = run_code('puts 1', request_token: 'abc-123')

      expect(result['request_token']).to eq 'abc-123'
    end

    it 'reports the elapsed time in milliseconds' do
      result = run_code('puts 1')

      expect(result['duration_ms']).to be_a(Integer)
      expect(result['duration_ms']).to be >= 0
    end

    it 'reports no truncation when the output fits within the cap' do
      result = run_code('puts "short"')

      expect(result['truncated']).to eq('stdout' => false, 'stderr' => false)
    end

    it 'writes a runtime error to stderr and leaves stdout empty' do
      result = run_code('raise "boom"')

      expect(result['stdout']).to eq('')
      expect(result['stderr']).to include('boom')
      expect(result['exit_status']).to eq 1
    end

    it 'writes a syntax error to stderr' do
      result = run_code("def broken\n")

      expect(result['stderr']).to include('syntax error')
      expect(result['exit_status']).to eq 1
    end

    it 'does not emit warnings for unused variables, which would corrupt grading' do
      result = run_code("unused = 1\nputs 'ok'")

      expect(result['stderr']).to eq('')
    end
  end

  describe 'timeout enforcement' do
    it 'kills a source that loops forever' do
      result = run_code('loop {}', timeout_ms: 1_000)

      expect(result['timed_out']).to be true
      expect(result['signal']).to eq 'KILL'
      expect(result['exit_status']).to be_nil
    end

    it 'kills a source that sleeps without consuming CPU time' do
      result = run_code('sleep 60', timeout_ms: 1_000)

      expect(result['timed_out']).to be true
      expect(result['signal']).to eq 'KILL'
    end

    it 'kills a source that ignores SIGTERM' do
      result = run_code("trap('TERM') {}\nloop {}", timeout_ms: 1_000)

      expect(result['timed_out']).to be true
      expect(result['signal']).to eq 'KILL'
    end

    it 'kills a source that swallows every exception' do
      result = run_code("begin\n  loop {}\nrescue Exception\n  retry\nensure\n  loop {}\nend", timeout_ms: 1_000)

      expect(result['timed_out']).to be true
      expect(result['signal']).to eq 'KILL'
    end

    it 'returns before the Lambda function timeout even when the source escapes its process group' do
      source = <<~RUBY
        fork do
          Process.setsid
          $stdout.close
          $stderr.close
          sleep 60
        end
        sleep 60
      RUBY

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = run_code(source, timeout_ms: 1_000)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(result['timed_out']).to be true
      expect(elapsed).to be < 5
    end
  end

  describe 'memory limits' do
    # RLIMIT_AS を下げすぎると正当な解答が NoMemoryError で不正解判定になる。
    # Ruby 3.4 は起動時点で約 450MiB の仮想アドレス空間を予約するため、
    # 上限を縮めた分がそのままユーザーの使える領域から削られる。
    it 'lets a legitimate solution allocate a sizeable array' do
      result = run_code('puts Array.new(200 * 1024 * 1024 / 8, 0).size')

      expect(result['exit_status']).to eq 0
      expect(result['stderr']).to eq ''
    end

    it 'raises NoMemoryError in the child instead of taking down the execution environment' do
      source = <<~RUBY
        chunks = []
        loop { chunks << 'x' * 1_000_000 }
      RUBY

      result = run_code(source)

      expect(result['stderr']).to include('NoMemoryError')
      expect(result['timed_out']).to be false
    end

    it 'keeps serving subsequent invocations after a memory bomb' do
      run_code("chunks = []\nloop { chunks << 'x' * 1_000_000 }")

      expect(run_code('puts "still alive"')['stdout']).to eq("still alive\n")
    end
  end

  describe 'process limits' do
    it 'applies the process limit to the child' do
      result = run_code('puts Process.getrlimit(Process::RLIMIT_NPROC).inspect')

      expect(result['stdout'].strip).to eq [ CodeRunner::NPROC_LIMIT, CodeRunner::NPROC_LIMIT ].inspect
    end

    it 'stops the child from spawning unbounded threads' do
      # RLIMIT_NPROC は Linux ではスレッドも計上するため、スレッド爆弾もここで止まる
      source = <<~RUBY
        spawned = 0
        begin
          loop do
            Thread.new { sleep 60 }
            spawned += 1
          end
        rescue ThreadError
          $stdout.write("spawned=\#{spawned}\\n")
        end
      RUBY

      result = run_code(source, timeout_ms: 3_000)

      expect(result['stdout']).to match(/\Aspawned=\d+\n\z/)
      expect(result['stdout'][/\d+/].to_i).to be <= CodeRunner::NPROC_HEADROOM
    end

    it 'never lets a fork bomb exceed the process limit' do
      peak = 0
      sampler = Thread.new do
        loop do
          count = CodeRunner::ProcessTable.own_uid_task_count
          peak = count if count > peak
          sleep 0.02
        end
      end

      begin
        run_code('loop { fork { sleep 60 } }', timeout_ms: 1_000)
      ensure
        sampler.kill
        sampler.join
      end

      # own_uid_task_count は sampler スレッド自身も数えるので 1 つ分を許容する
      expect(peak).to be <= CodeRunner::NPROC_LIMIT + 1
    end

    it 'keeps serving subsequent invocations after a fork bomb' do
      run_code('loop { fork { sleep 60 } }', timeout_ms: 1_000)

      expect(run_code('puts "still alive"')['stdout']).to eq("still alive\n")
    end

    it 'kills a grandchild that escaped the process group with setsid' do
      source = <<~RUBY
        pid = fork do
          Process.setsid
          $stdout.close
          $stderr.close
          sleep 60
        end
        puts pid
      RUBY

      result = run_code(source)
      escaped_pid = result['stdout'].to_i

      expect(escaped_pid).to be > 0
      expect(process_alive?(escaped_pid)).to be false
    end
  end

  describe 'file and descriptor limits' do
    it 'stops the source from writing a file larger than the size limit' do
      result = run_code("File.binwrite('big', 'x' * #{CodeRunner::FILE_SIZE_BYTES + 1_000_000})")

      expect(result['signal'] == 'XFSZ' || result['stderr'].include?('File too large')).to be true
    end

    it 'stops the source from opening more descriptors than the limit' do
      source = <<~RUBY
        handles = []
        begin
          loop { handles << File.open('main.rb') }
        rescue Errno::EMFILE
          puts "opened=\#{handles.size}"
        end
      RUBY

      result = run_code(source)

      expect(result['stdout']).to match(/\Aopened=\d+\n\z/)
      expect(result['stdout'][/\d+/].to_i).to be < CodeRunner::OPEN_FILES
    end
  end

  describe 'output capping' do
    # answer_results.output の Rails 側バリデーション。これを 1 文字でも超えると
    # update! が RecordInvalid になり、CorrectnessCheckJob の retry で同じコードが
    # 3 回実行されたうえで status: error になる。
    RAILS_OUTPUT_MAX_CHARS = 65_535

    it 'caps stdout at the character limit and flags it as truncated' do
      result = run_code("20_000.times { puts 'x' * 100 }")

      expect(result['stdout'].length).to eq CodeRunner::RESPONSE_MAX_CHARS
      expect(result['truncated']['stdout']).to be true
    end

    it 'keeps the response within the length Rails can store' do
      result = run_code("20_000.times { puts 'x' * 100 }")

      expect(result['stdout'].length).to be <= RAILS_OUTPUT_MAX_CHARS
    end

    # scrub は不正バイト 1 つを U+FFFD（3 バイト）に置き換えるため、バイトだけで
    # 締めていると最終的な文字列が上限を超える。
    it 'keeps the response within the limit even when invalid bytes are scrubbed' do
      result = run_code("$stdout.binmode\n200_000.times { $stdout.write(\"\\xff\") }")

      expect(result['stdout'].length).to be <= RAILS_OUTPUT_MAX_CHARS
      expect(result['stdout'].valid_encoding?).to be true
    end

    it 'keeps draining the pipe so a flooding source still runs to completion' do
      result = run_code("20_000.times { puts 'x' * 100 }")

      expect(result['exit_status']).to eq 0
      expect(result['timed_out']).to be false
    end

    it 'caps stderr independently of stdout' do
      result = run_code("20_000.times { $stderr.puts 'e' * 100 }")

      expect(result['stderr'].length).to eq CodeRunner::RESPONSE_MAX_CHARS
      expect(result['truncated']).to eq('stdout' => false, 'stderr' => true)
    end
  end

  describe 'encoding' do
    it 'returns valid UTF-8 even when the source writes invalid bytes' do
      result = run_code("$stdout.binmode\n$stdout.write(\"\\xff\\xfe\")")

      expect(result['stdout'].encoding).to eq Encoding::UTF_8
      expect(result['stdout'].valid_encoding?).to be true
    end

    it 'preserves multibyte characters that fit within the cap' do
      result = run_code('puts "こんにちは"')

      expect(result['stdout']).to eq("こんにちは\n")
    end

    # NUL は valid_encoding? を通り scrub でも消えないが、PostgreSQL の text は
    # 符号位置 0 を保持できないため、そのまま返すと保存が壊れる。
    it 'replaces NUL bytes that PostgreSQL cannot store' do
      result = run_code("$stdout.binmode\n$stdout.write(\"a\\u0000b\")")

      expect(result['stdout']).not_to include("\u0000")
      expect(result['stdout']).to eq("a\uFFFDb")
    end
  end

  describe 'environment isolation' do
    it 'hands the child only the environment variables it needs' do
      result = run_code('puts ENV.keys.sort.join(",")')

      expect(result['stdout'].strip).to eq 'HOME,LANG,PATH,TZ'
    end

    it 'does not leak AWS credentials through the environment' do
      result = run_code('puts ENV["AWS_SECRET_ACCESS_KEY"].inspect')

      expect(result['stdout']).to eq("nil\n")
    end

    it 'does not hand the child any descriptor the handler holds open' do
      handler_held = Tempfile.new('handler-held')

      begin
        source = <<~RUBY
          links = Dir.children('/proc/self/fd').map do |fd|
            File.readlink("/proc/self/fd/\#{fd}")
          rescue SystemCallError
            ''
          end
          puts links.join("\\n")
        RUBY

        result = run_code(source)

        expect(result['stdout']).not_to include(handler_held.path)
      ensure
        handler_held.close!
      end
    end

    it 'creates files that no other user can read' do
      result = run_code("File.write('f', 'x')\nputs format('%o', File.stat('f').mode & 0o777)")

      expect(result['stdout'].strip).to eq '600'
    end
  end

  describe 'handler process protection' do
    # ptrace の実攻撃はテストしない。防御が壊れていると PTRACE_ATTACH の SIGSTOP で
    # ハンドラ（= このテストプロセス）が停止し、スイートごと戻らなくなるため。
    # 代わりに、ptrace と同じ権限判定（ptrace_may_access）を通る /proc 読み取りと
    # dumpable フラグそのものを検証する。
    it 'marks the handler process as non-dumpable' do
      prctl = Fiddle::Function.new(
        Fiddle::Handle.new(nil)['prctl'],
        [ Fiddle::TYPE_INT ] * 5,
        Fiddle::TYPE_INT
      )

      # PR_GET_DUMPABLE = 3
      expect(prctl.call(3, 0, 0, 0, 0)).to eq 0
      expect(CodeRunner::PTRACE_PROTECTED).to be true
    end

    it 'stops the child from reading the handler environment through /proc' do
      source = <<~RUBY
        begin
          File.read("/proc/\#{Process.ppid}/environ")
          puts 'READABLE'
        rescue SystemCallError => e
          puts "DENIED: \#{e.class}"
        end
      RUBY

      result = run_code(source)

      expect(result['stdout']).to start_with('DENIED')
    end

    it 'stops the child from reading the handler memory through /proc' do
      source = <<~RUBY
        begin
          File.open("/proc/\#{Process.ppid}/mem", 'rb') { |f| f.read(1) }
          puts 'READABLE'
        rescue SystemCallError => e
          puts "DENIED: \#{e.class}"
        end
      RUBY

      result = run_code(source)

      expect(result['stdout']).to start_with('DENIED')
    end
  end

  describe 'workspace hygiene' do
    it 'removes the working directory after the invocation' do
      run_code("File.write('payload', 'x')")

      expect(Dir.glob(File.join(tmp_root, 'run-*'))).to be_empty
    end

    it 'removes files the source left directly under the temporary root' do
      run_code("File.write('#{File.join(CodeRunner::TMP_ROOT, 'payload.txt')}', 'x')")

      expect(File.exist?(File.join(tmp_root, 'payload.txt'))).to be false
    end

    it 'does not let one invocation read a payload left by an earlier one' do
      payload = File.join(CodeRunner::TMP_ROOT, 'shared.txt')
      run_code("File.write('#{payload}', 'secret')")

      result = run_code("puts File.exist?('#{payload}')")

      expect(result['stdout']).to eq("false\n")
    end

    # ハンドラが Lambda 関数タイムアウトや親殺しで落とされると cleanup を完走できない。
    # その残骸を次のユーザーコードと同時に走らせないよう、invoke の開始時にも掃除する。
    it 'wipes a payload left behind by a crashed invocation before running the source' do
      leftover = File.join(CodeRunner::TMP_ROOT, 'leftover.txt')
      File.write(leftover, 'secret')

      result = run_code("puts File.exist?('#{leftover}')")

      expect(result['stdout']).to eq("false\n")
    end
  end

  describe 'input validation' do
    it 'rejects an event without a source' do
      expect { lambda_handler(event: {}, context: nil) }.to raise_error(ArgumentError, /source/)
    end

    # String#[]("source") は部分文字列マッチで "source" を返すため、Hash かどうかを
    # 先に確かめないと型チェックをすり抜けて、その文字列がそのまま実行されてしまう。
    it 'rejects an event that is not a Hash' do
      expect { lambda_handler(event: 'source', context: nil) }.to raise_error(ArgumentError, /Hash/)
    end

    it 'rejects a source that is not a String' do
      expect { lambda_handler(event: { 'source' => 123 }, context: nil) }.to raise_error(ArgumentError, /String/)
    end

    it 'rejects a timeout_ms that is not numeric' do
      event = { 'source' => 'puts 1', 'timeout_ms' => {} }

      expect { lambda_handler(event: event, context: nil) }.to raise_error(ArgumentError, /numeric/)
    end

    it 'rejects a source longer than the allowed length' do
      event = { 'source' => 'a' * (CodeRunner::SOURCE_MAX_LENGTH + 1) }

      expect { lambda_handler(event: event, context: nil) }.to raise_error(ArgumentError, /too long/)
    end

    it 'rejects a stdin longer than the allowed length' do
      event = { 'source' => 'puts 1', 'stdin' => 'a' * (CodeRunner::STDIN_MAX_LENGTH + 1) }

      expect { lambda_handler(event: event, context: nil) }.to raise_error(ArgumentError, /too long/)
    end

    it 'falls back to the default timeout when none is given' do
      result = lambda_handler(event: { 'source' => 'puts 1' }, context: nil)

      expect(result['stdout']).to eq("1\n")
      expect(result['timed_out']).to be false
    end

    it 'caps a timeout larger than the maximum' do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      run_code('sleep 60', timeout_ms: 60_000)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(elapsed).to be < CodeRunner::MAX_TIMEOUT_MS / 1000.0 + CodeRunner::KILL_GRACE_SECONDS + 1
    end
  end
end
