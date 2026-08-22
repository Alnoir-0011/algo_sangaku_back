# code_runner

第三者が投稿した Ruby コードを AWS Lambda 上で隔離実行するサンドボックス。
現在 PaizaIO が担っているコード実行を置き換えるためのもの（Epic #317）。

## 設計の前提: Ruby レベルのサンドボックスは成立しない

Ruby には権限モデルが存在しない。

- `$SAFE` は Ruby 3.0 で「特別な意味を持たない通常のグローバル変数」に降格、`taint` は 3.2 で完全削除
- `Kernel#system` や `File` を `undef_method` で潰しても、default gem の **`fiddle`** で
  `Fiddle::Handle.new(nil)` から libc の任意関数（`execve` / `connect` / `ptrace` 等）を直接呼べる
- `const_get` / `__send__` / `bind_call` / `TracePoint` / `ObjectSpace` / `RubyVM::InstructionSequence`
  などの復元経路も塞げない

したがって **有効な境界は OS プロセス境界だけ**という前提で作ってある。ハンドラ（信頼）と
ユーザーコード（非信頼）を別プロセスに分け、rlimit と SIGKILL、実行後の掃除で封じ込める。

## プロセス構成

```
Lambda 実行環境
└─ ruby（Lambda ruby3.4 ランタイム）  … ハンドラ = 信頼コード
   └─ [fork+exec] ruby main.rb        … 信頼できないユーザーコード
         stdin  ← workdir/stdin.txt（ファイル）
         stdout → pipe（64KiB キャップ、超過後も読み捨て継続）
         stderr → pipe（同上）
```

## 入出力

入力（**期待値は絶対に含めない**。理由は後述の残存リスクを参照）:

```json
{"source": "...", "stdin": "...", "timeout_ms": 5000, "request_token": "<uuid>"}
```

出力:

```json
{"stdout": "...", "stderr": "...", "exit_status": 0, "signal": null,
 "timed_out": false, "truncated": {"stdout": false, "stderr": false},
 "duration_ms": 123, "request_token": "<uuid>"}
```

`source` / `stdin` は各 65,535 文字まで（Rails 側の `answers.source` / `fixed_inputs.content` の
バリデーションと揃えてある）。`timeout_ms` は 5,000 で頭打ち。`event` が Hash でない場合や
`source` / `timeout_ms` の型が違う場合は `ArgumentError` で弾く。

### 出力の締め方には順序がある

`stdout` / `stderr` は **2 段階**で切る。

1. パイプから読む段階で **64 KiB（バイト）**。ここで打ち切らないとハンドラ側のメモリを食い潰す。
   上限に達しても**読み捨ては継続する**（読むのを止めるとパイプが満杯になって子がブロックし、
   kill 処理とデッドロックする）
2. レスポンスを組み立てる段階で **60,000 文字**

2 段階目が要る理由は、`answer_results.output` の Rails 側バリデーションが**バイト数ではなく
文字数**（65,535）だからである。バイトだけで締めると次のどちらでも上限を超える。

- ASCII で 64 KiB = **65,536 文字**ちょうどで、上限を 1 文字超える
- 不正バイトの `scrub` で 1 バイトが U+FFFD（3 バイト）に膨らむ。64 KiB の不正バイトは
  実測で **196,608 バイト / 65,536 文字**になる

超えると `update!` が `RecordInvalid` になり、`CorrectnessCheckJob` の `retry_on` で
**同じコードが 3 回実行された末に `status: error`** になる。`puts "x" * 100_000` を投稿する
だけで踏めるので、Lambda 側で確実に下回らせている。

最終文字列は次の順で作る。順序を変えると上の保証が壊れる。

1. 不正な UTF-8 を `scrub`（バイト数が最大 3 倍になる）
2. **NUL を U+FFFD に置換**。`valid_encoding?` は NUL に対して true を返し `scrub` でも
   消えないが、PostgreSQL の `text` は符号位置 0 を保持できない
3. 最後に**文字数**で締める

## リソース上限

| キー | 値 | 理由 |
|---|---|---|
| `rlimit_cpu` | `[5, 6]` | ソフト 5s で SIGXCPU、**ハード 6s でカーネルが SIGKILL**。`trap("XCPU"){}` による回避を無効化する |
| `rlimit_as` | **768 MiB** | 下の「実測メモ」を参照。設計時の想定は 512MiB だったが狭すぎた |
| `rlimit_nproc` | 自 UID のタスク数 + 8 | fork bomb 対策。Linux では**スレッドも計上される**ので Init 時に `/proc` を数えて動的算出する |
| `rlimit_fsize` | 8 MiB | 1 ファイルあたり。`/tmp`（512MB）を 1 ファイルで埋められないようにする |
| `rlimit_nofile` | 64 | Lambda 全体の fd 上限 1,024 を子 1 つで食わせない |
| `rlimit_core` | 0 | core dump による `/tmp` 圧迫を防ぐ |
| `rlimit_stack` | **指定しない** | 下げると正当な深い再帰が `SystemStackError` になり採点結果が変わる |

`Process.spawn` 側は `unsetenv_others: true` / `pgroup: true` / `chdir:` / `close_others: true` /
`umask: 0o077`、stdin は**パイプではなくファイル**（パイプにすると子が読まない大入力で親の
write がブロックしデッドロックする）。

## タイムアウトは三重

Ruby の `Timeout` を子プロセスの内部に仕込む方式は無効で、公式ドキュメントも
*"this method cannot be relied on to enforce timeouts for untrusted blocks"* と明記している
（`rescue Exception` / `ensure` で握り潰せる）。

1. `rlimit_cpu: [5, 6]` — CPU 時間のハード上限（カーネルが SIGKILL）
2. **ハンドラ側の壁時計デッドライン**（`CLOCK_MONOTONIC` + `waitpid(WNOHANG)` ポーリング →
   `kill("KILL", -pgid)`）— `sleep` 等 CPU を使わない待機も止める
3. Lambda 関数タイムアウト 10s — ハンドラ自体が壊れた場合の最終防波堤

**SIGTERM は一切送らない**（`trap("TERM"){}` で無視されるため）。SIGKILL のみを使う。

## 実行環境の衛生（warm start 対策）

Lambda は `/tmp` を次の呼び出しに持ち越し、「完了しなかったバックグラウンドプロセスは
実行環境が再利用されると再開する」。そのため invoke ごとに必ず後始末する。

| タイミング | 処理 |
|---|---|
| Init（1 回） | **`/tmp` 直下を無条件に全削除**してから `/proc` の PID セットをベースラインとして凍結 |
| invoke 開始 | ① ベースライン外の自 UID プロセスを SIGKILL ② `/tmp` 直下を全削除 ③ `/tmp/run-<uuid>` を mode 0700 で作成し `main.rb` / `stdin.txt` を書く |
| invoke ensure | ① `kill("KILL", -pgid)` ② ベースライン外の自 UID プロセスを SIGKILL ③ ゾンビを回収 ④ `/tmp` 直下を全削除 |

**Init で `/tmp` を無条件に消すのが重要。** 「ベースラインを採って差分だけ消す」方式だと、
ユーザーコードが `Process.kill("KILL", ppid)` で cleanup を回避してファイルを残した場合、
次の Init でその残骸が**ベースラインに昇格して以後の掃除対象から永久に外れる**。
（`/tmp` を使う Lambda Extension を足す場合はこの挙動を見直すこと。）

**invoke の開始時にも掃除する。** cleanup は ensure にあるが、ハンドラごと殺されれば
（Lambda 関数タイムアウト、親殺し）走らない。開始時にも掃除しておくと、残骸が次のユーザーの
コードと同時に動いて `/tmp` の `main.rb` や `stdin.txt` を読まれる窓が閉じ、前回の失敗が
自動的に是正される。

プロセスのスイープは「ベースラインに無い」ことに加えて「ハンドラ自身の `starttime` 以降に
生まれた」ことを条件にしている。前者だけだと Lambda 以外の環境（CI ランナー等）で無関係な
プロセスを巻き込みうるため。**`starttime` が読めなかった場合は見逃さず殺す**（fail-close）。
ベースライン外と分かっている以上、取りこぼす方が危険なので。

ゾンビも RLIMIT_NPROC を消費するため、cleanup では 0.2 秒の予算内で `waitpid` を繰り返す。
`NPROC_HEADROOM` が 8 しかないので、取りこぼすと次の提出が使えるタスク数がそのまま減る。

## 防げないもの（受け入れる残存リスク）

これらは**このコードでは塞げない**。IAM とネットワークの層で無害化する前提になっている（#320）。

| 攻撃 | なぜ防げないか | どう無害化するか |
|---|---|---|
| `127.0.0.1:9001`（Lambda Runtime API、認証なし）への直接アクセス | ネットワーク名前空間の分離が Lambda で使えない（`unshare` が EPERM） | **期待値（正解の stdout）を絶対に Lambda に渡さない。** 正誤比較は Rails 側で行う |
| `Process.kill("KILL", Process.ppid)` による親殺し | シグナル送信の権限判定は UID だけを見るので、`PR_SET_DUMPABLE` では防げない | 被害はその提出 1 件の採点失敗のみ（自分自身の DoS）。ハンドラは即座に死ぬので実行環境を占有しない |
| 多数ファイル作成による `/tmp` の合計枯渇 | `rlimit_fsize` は 1 ファイルあたりの制限 | invoke ごとの `/tmp` ワイプ |
| `/proc/<ppid>/environ` からの AWS 認証情報窃取 | **本番の Lambda では `prctl` が使えない**（後述） | 実行ロールの権限をほぼ空にしてある。窃取できるのは特定ロググループへの `logs` 書き込みのみ（#320） |
| `PTRACE_ATTACH` によるハンドラ停止 | 同上 | 被害は実行環境を関数タイムアウト（10 秒）まで占有すること。reserved concurrency 5 なので採点の遅延に留まる |

> **重要**: 設計当初は上記 2 つを `PR_SET_DUMPABLE` で塞げるとしていたが、**本番の Lambda では
> `prctl` 自体が拒否される**ことが実測で分かったため、ここに戻した。詳細は次節。

## ハンドラプロセスの保護（`PR_SET_DUMPABLE`）

子とハンドラは同一 UID なので、既定では子がハンドラを `PTRACE_ATTACH` できる。これは
メモリの覗き見に留まらない。**`PTRACE_ATTACH` は対象に SIGSTOP を送る**ため、ユーザーコードが
ハンドラを停止させ、Lambda 関数タイムアウトまで実行環境を占有できてしまう。reserved
concurrency は 5 なので、5 並列すべてを止めれば採点全体を停止させる DoS になりうる。

Init フェーズで `prctl(PR_SET_DUMPABLE, 0)` を一度呼ぶと `ptrace_may_access()` が
EPERM を返すようになり、同じ判定を通る `/proc/<ppid>/*` の読み取りもまとめて塞がる。

| 攻撃 | 保護なし | `PR_SET_DUMPABLE=0` |
|---|---|---|
| `/proc/<ppid>/environ`（AWS 認証情報） | 読める | **EACCES** |
| `/proc/<ppid>/mem` | 権限あり | **EACCES** |
| `ptrace(PTRACE_ATTACH, ppid)` | **成功してハンドラが停止する** | **EPERM** |
| 攻撃後のハンドラ | 戻ってこない | **正常に次の invoke を処理する** |

### ⚠ 本番の Lambda ではこの保護は効いていない

上表は `Dockerfile.test`（Lambda 公式イメージ + Docker）での実測値である。
**本番のマネージドランタイムでは `prctl` が拒否され、保護は成立していない。**
2026-08-22 に実環境で確認した結果は以下のとおり。

```
PR_SET_DUMPABLE returned -1 (errno=1 EPERM)
PR_GET_DUMPABLE returned -1
```

`PR_GET_DUMPABLE` は引数が正しければ 0/1/2 を返すだけで失敗しようがない呼び出しであり、
それも -1 になっている。したがって特定のオプションが拒否されているのではなく、
**`prctl` の呼び出しそのものが通っていない**。またカーネルの `PR_SET_DUMPABLE` は引数不正なら
`EINVAL` を返す実装で `EPERM` を返す経路が無いため、カーネルに届く前に
seccomp 等のフィルタで弾かれていると考えられる。**ハンドラ側では回避できない。**

Docker で再現しないのは、Docker の既定 seccomp プロファイルが `prctl` を許可しているため。
**テストが通っても本番で成立するとは限らない**典型例なので、`spec` の
「marks the handler process as non-dumpable」が通っていることを根拠に安全と判断しないこと。

保護が効いているかは、実行環境ごとに `PR_GET_DUMPABLE` で読み戻して確認している。
失敗時は理由を添えて stderr に出るので、CloudWatch で追える（通知は #335 で対応）。

結果として `/proc/<ppid>/environ` からの認証情報窃取と `PTRACE_ATTACH` は
「防げないもの」に戻っている。**#320 の IAM 設計（実行ロールの権限をほぼ空にする）は
最終防衛線ではなく、この 2 つに対する主たる防御である。**

### ⚠ Ruby 4.0 で `fiddle` が default gem から外れる

`prctl` を呼ぶ手段が Ruby には `fiddle` しかないため、この保護は `fiddle` に依存している。
**`fiddle` は Ruby 4.0.0 で default gem ではなくなる**（Ruby 3.4 でも `require` すると警告が出る）。

本番の zip には gem を同梱しない設計なので、Lambda ランタイムを **ruby4.x に上げるときは
`fiddle` がランタイムに含まれているかを必ず確認すること。** 失敗の仕方は 2 通りに分かれる。

| 状況 | 挙動 | 理由 |
|---|---|---|
| `fiddle` 自体が無い | **関数が起動しない**（実測で確認） | `LoadError` は `StandardError` ではなく `ScriptError` のサブクラスなので `protect_from_ptrace` の `rescue` を素通りする |
| `fiddle` はあるが `prctl` を呼べない | 警告を出して**保護なしで継続** | `Fiddle::DLError` は `StandardError` のサブクラスなので捕捉され `false` になる |

前者は採点が完全に止まるが、**保護が無い状態で第三者のコードを実行するよりは安全**なので、
この挙動は意図して残している（`rescue` を広げて握り潰さないこと）。

後者に気づけるよう 2 か所で検知している。

- **本番**: Init 時に stderr へ警告を出す（CloudWatch Logs に残る）
- **CI**: `PTRACE_PROTECTED` が `true` であることを spec で assert している

ランタイムに `fiddle` が含まれない場合の対応は、zip に同梱するか、prctl を呼ぶ別の手段
（拡張ライブラリを同梱する等）に切り替えるかのどちらかになる。

## Ruby レベルでは何も塞いでいない

`system` / `` ` `` / `Kernel.system` / `Process.spawn` / `RubyVM::InstructionSequence.eval` /
`fiddle` 経由の libc 直接呼び出しは、**すべて実行できる**。これは意図的な設計で、ブロックリスト方式は
原理的に破綻するため採らない（`fiddle` で libc を直接呼べる時点で、どれだけメソッドを潰しても
迂回できる）。危険なのは「防御できている」という錯覚の方で、封じ込めは OS 層だけに寄せている。

実際に確認した挙動は Notion の「危険なコードに対する攻撃手段と対策（実測記録）」を参照。

## 実測メモ（実装時に判明した落とし穴）

`Dockerfile.test`（Lambda 公式イメージ = AL2023 / glibc / Ruby 3.4.10 / arm64）で確認した。

### インタプリタは絶対パスで起動する必要がある

Lambda の ruby は `/var/lang/bin/ruby` にあり、`unsetenv_others: true` で子に渡す `PATH` は
`/usr/bin:/bin` なので、`"ruby"` では解決できない。`RbConfig.ruby` を使っている。

### Ruby 3.4 は起動しただけで仮想アドレス空間を 450MiB 予約する

`RLIMIT_AS` は仮想アドレス空間の制限なので、この予約分がそのままユーザーの取り分から削られる。
404MiB の匿名マッピング 1 本が大半で、`MALLOC_ARENA_MAX` では減らない。

| `rlimit_as` | ユーザーコードが確保できた最大配列 |
|---|---|
| 512 MiB（設計時の想定） | 50 MiB |
| 640 MiB | 100 MiB |
| **768 MiB（採用）** | **300 MiB** |
| 1,024 MiB | 500 MiB |

競技プログラミングの標準的なメモリ制限 256MB を満たせる 768MiB を採用した。どの値でも
メモリ爆弾は `NoMemoryError` になり、実行環境は生き残って stderr を返せる。

### `RLIMIT_NPROC` 到達時、`fork` は例外を投げずにハングすることがある

`Thread.new` は素直に `ThreadError` になるが、`fork` は `Errno::EAGAIN` を投げないまま
プロセスが固まる場合がある。**封じ込め自体は成立している**（それ以上プロセスは増えない）が、
ユーザーからは「タイムアウト」として見える。壁時計デッドラインの SIGKILL が効くので
実行環境への影響はない。

## ローカルでの検証

**macOS では動かない。** `RLIMIT_AS` が Linux 専用で `Process.spawn` 自体が失敗するため、
必ず Docker（Linux）上で実行する。また `RLIMIT_NPROC` は **root では無視される** per-UID の
制限なので、非 root で動かさないと fork bomb 対策の検証にならない
（`Dockerfile.test` は `sandbox` = uid 1000 に切り替えてある）。

```bash
# イメージビルド
docker build -f lambda/code_runner/Dockerfile.test -t code-runner-test lambda/code_runner

# テスト（非 root / glibc / ruby 3.4）
docker run --rm --memory 1769m --entrypoint /bin/bash code-runner-test \
  -c "cd /var/task && bundle exec rspec"

# 非 root で動いていることの確認（root だと rlimit_nproc の検証が無効になる）
docker run --rm --entrypoint /bin/bash code-runner-test -c "id -u"   # => 1000

# RIE 経由の疎通スモーク
docker run -d --name code-runner-rie -p 9077:8080 code-runner-test handler.lambda_handler
curl -s -X POST "http://localhost:9077/2015-03-31/functions/function/invocations" \
  -d '{"source":"puts gets.to_i * 2","stdin":"21\n","timeout_ms":5000,"request_token":"smoke"}'
docker rm -f code-runner-rie
```

CI では Docker を使わず **`ubuntu-24.04-arm` 上で直接**実行している（`.github/workflows/ci.yml` の
`lambda_code_runner` ジョブ）。ランナーは非 root + glibc なので rlimit 系はそのまま検証できる。

**arm64 ランナーを使うのは本番の Lambda が arm64 だから。** `rlimit_as` の値は「Ruby 3.4 が
起動時に予約する仮想アドレス空間」を実測して決めており、この予約量はアーキテクチャによって
変わる。amd64 で緑になっても arm64 の本番を保証しない。

> 補足: Apple Silicon 上の Docker で `--platform linux/amd64` を指定すると、エミュレーション層が
> `RLIMIT_AS` を握り潰して `soft=17592186044415MiB`（実質無制限）になり、rlimit の検証自体が
> 成立しない。ローカル検証は必ず arm64 ネイティブで行うこと。

### act でワークフロー自体を確認する

```bash
act push -j lambda_code_runner \
  -P ubuntu-24.04-arm=catthehacker/ubuntu:act-latest \
  --container-architecture linux/arm64
```

**act のランナーコンテナは root で動くため、`RLIMIT_NPROC` の検証 2 件はスキップされる**
（root では per-UID の制限が無視されるので、通しても検証にならない）。ワークフローの構文と
ステップの疎通確認には使えるが、fork bomb 対策の検証には `Dockerfile.test`（非 root）を使うこと。

スキップされた場合は spec 実行時に警告が出る。本物の GitHub Actions のランナーは非 root
（`runner`）なので、CI ログにこの警告が出ていたら前提が崩れているサインになる。

## デプロイ

Terraform の `archive_file` で zip 化してマネージドランタイムにデプロイする（#320 で構築済み。
実体は `terraform/lambda.tf`）。**CI ではコードを触らない。**変更頻度が極めて低いサンドボックスの
ために drift 源を増やしたくないため。頻繁に変えるフェーズに入ったら `update-function-code` +
`ignore_changes` 方式に移行する。`handler.rb` を変更したら `terraform apply` で反映する
（`source_code_hash` が変わって関数コードが差し替わる）。

```hcl
data "archive_file" "code_runner" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/code_runner/ruby"
  output_path = "${path.module}/.build/code_runner.zip"

  # テスト用のファイルは本番の zip に含めない
  excludes = ["spec", "Gemfile", "Gemfile.lock", ".rspec"]
}
```

### VPC 接続の副作用: 日次ウォームアップ

VPC に接続した関数は **14 日アイドルすると Hyperplane ENI が回収され、`Inactive` になって
次の呼び出しが失敗する**（AWS 公式が明記）。EventBridge Scheduler が 1 日 1 回
`{"warmup": true}` を投げてこれを防ぐ（`terraform/lambda.tf` の
`aws_scheduler_schedule.code_runner_warmup`）。

`lambda_handler` は `warmup` を見たら **`Sandbox` に入る前に即 return する**。ウォームアップ用の
イベントは `source` を持たないので、そのまま渡すと `ArgumentError` になる。

### インフラ側で必ず満たすこと（#320 の受入条件）

ユーザーコードは**インターネットへ自由に出られる**（`/usr/bin/curl` も存在する）。Lambda に
IMDS は無いので認証情報の奪取に直結はしないが、提出コードや `/tmp` の中身を外部送信でき、
踏み台・スキャン・マイニングへの転用も可能になる。ハンドラ側では塞げないので、以下は
インフラ側の必須要件として扱う。

- **既存 VPC を流用しない。** 流用した瞬間に RDS / ECS への到達性が生まれる。VPC に入れない
  か、入れるなら経路を持たない専用サブネット + egress ルールゼロの SG に置く
  → `terraform/vpc.tf` の `sandbox_a` / `sandbox_c` + ルート無しの `aws_route_table.sandbox`、
  `terraform/security_groups.tf` の `aws_security_group.code_runner`
- **実行ロールは特定ロググループへの `logs` 以外をゼロにする。** 本番では `prctl` が使えず
  `/proc/<ppid>/environ` を塞げないため、これは最終防衛線ではなく**主たる防御**である
  → `terraform/iam.tf` の `aws_iam_role.code_runner`。ただし VPC 接続には ENI 操作
  （`ec2:CreateNetworkInterface` 等）が必須なので厳密に `logs` だけにはできない。保険の
  Deny は `NotAction = ["logs:*", "ec2:*"]` とし、`ec2:*` は `lambda:SourceFunctionArn`
  条件付き Deny で「ユーザーコード由来の呼び出しだけ」を拒否している
- リソースベースポリシーで invoke 元を ECS タスクロールに限定する
  → `aws_lambda_permission` で付与済み。ただし**同一アカウント内では identity ベースで
  許可されていれば invoke は通る**ため、これ単体では限定にならない。実質的な限定は
  `aws_iam_role_policy.ecs_task_invoke_code_runner` の Resource 限定が担う
- reserved concurrency 5（コスト上限とキルスイッチを兼ねる）
  → `var.code_runner_reserved_concurrency`。`0` にすれば呼び出しを止められる

### Rails 側で必ず満たすこと（#322 / #323 の受入条件）

- **期待値（正解の stdout）を絶対に Lambda に渡さない。** ユーザーコードは
  `127.0.0.1:9001` の Runtime API に到達できるため、渡した時点で漏れる
- **`request_token` の一致を検証する。** ハンドラはエコーバックするだけで検証していない。
  取り違えの検知は Rails 側の責務
- Runtime API 経由でレスポンス自体を偽造される可能性は残る。**当初は「子から読めない環境変数に
  秘密鍵を置いて HMAC を付ける」案を挙げていたが、本番では `prctl` が使えず
  `/proc/<ppid>/environ` を塞げないため、この案は成立しない。** ハンドラの環境変数に秘密鍵を
  置いても子から読める。偽造を検知したい場合は、秘密をハンドラ内に持たない方式
  （Rails 側で入力と出力の突き合わせを行う等）を検討すること
- 出力は Lambda 側で 60,000 文字に収めているが、`answer_results.output` 側の truncate も
  #323 で入れておくと二重に安全

### その他

- **ハンドラ名は `handler.lambda_handler`**（`handler.rb` が zip のルートに来る）
- ハンドラ本体は stdlib のみで動くので、zip に gem を同梱する必要はない
- 多言語対応するときは `lambda/code_runner/{python,...}/` と兄弟ディレクトリで並べ、
  言語ごとに別 Lambda 関数としてデプロイする
