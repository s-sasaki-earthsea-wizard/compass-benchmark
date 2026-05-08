# compass-benchmark — Claude向けプロジェクト指針

## プロジェクト概要

[opera-adt/COMPASS](https://github.com/opera-adt/COMPASS) の SAFE → CSLC 化処理を
プロファイリングするためのベンチマーク・ハーネス。COMPASS本家のfork **ではなく**、
sibling (隣接) する独立リポジトリ。物理的には `COMPASS/compass-benchmark/` に
ネスト配置されるが、`COMPASS/.git/info/exclude` で非追跡化されている。

## 言語設定

このプロジェクトでは **日本語** での応答を行うこと。

ただし以下は **英語で記述する**:

- コード内コメント (`.py`, `.sh`, `Dockerfile`, `Makefile`, `.yaml/.yml` 等)
- Pythonのdocstring
- コードが出力するログメッセージ・エラーメッセージ・print文

理由: 本リポジトリはOSSとして公開され `opera-adt/COMPASS` の隣に置かれる sibling であり、
将来的に英語圏のOSSコントリビュータが読む可能性が高い。コードに日本語が混在すると
そこが摩擦点になるため、コードレベルは英語に統一する。

一方、以下は **日本語で記述する**:

- `README.md`, `CLAUDE.md`, `reports/*.md`, `.claude-notes/*.md` 等のmarkdownドキュメント
- ユーザー (s-sasaki-earthsea-wizard) との対話

## 基本ポリシー

### 触ってよい範囲

- `compass-benchmark/` 配下: 全て編集可。
- `COMPASS/CLAUDE.md`, `COMPASS/.claude-notes/`: 編集可
  (両者とも `COMPASS/.git/info/exclude` で非追跡化されておりupstreamへ漏れない)。

### 触ってはいけない範囲

- `COMPASS/` 配下のソースコード (`src/`, `tests/`, `docker/`, `pyproject.toml` 等):
  **読むだけ。編集禁止**。upstream PRの履歴を汚さないため。
- 環境分離のため、**ホストへのpython/condaパッケージインストールは禁止**。
  全てDockerコンテナ内で完結させること。

## 実行モデル

### 環境分離

- **COMPASS実行環境**: COMPASS本家の `docker/Dockerfile` でビルドされた
  `opera/cslc_s1:final_0.5.6` (Oracle Linux 8.8 + miniforge + conda env "COMPASS")。
- **bench派生イメージ**: 上記をベースに `compass-benchmark/docker/Dockerfile` で
  `requirements.txt` 記載のツール (`py-spy`, `snakeviz`, `gprof2dot`, `pyyaml`,
  `h5py`, `numpy`) を **plain pip** で COMPASS conda env に直接インストール。
  タグ: `compass-benchmark:latest`。Docker自体が環境分離を提供するため、
  uv等の追加venv層は意図的に入れていない。
- **ホスト**: Docker起動とファイルマウントのみ。Pythonランタイムを持たない。

### py-spyのptrace要件

`docker-compose.yml` で `cap_add: [SYS_PTRACE]` を必ず付けること。
これが無いと `py-spy record` が `Operation not permitted` で失敗する。

### OOM safety net

`scripts/lib/setup_ulimit.sh` でVAを物理RAMの80%に制限。
mintpy-benchmarkでの過去incident (RSSが物理RAMを超えhard reboot) を踏まえた予防策。
全ての `run_*.sh` の冒頭で `source` する。

## 出力ディレクトリ規約

- 各runは `${BENCH_LOG_BASE:-$HOME/compass-bench-logs}/logs_<tag>_<timestamp>/`
  に書く。**ホストローカルな POSIX FS 上に出力する**のがデフォルト。
  - 理由: 本リポジトリは CIFS (SMB) 上に置かれる運用が想定されており、
    py-spy + ptrace の signal 経路が CIFS の長時間 syscall (h5py の
    `_close_open_objects`) と競合し errno=103 (ECONNABORTED) で
    クラッシュする (issue #2、2026-05-09 セッションで原因特定)。
  - 解決策の選択履歴: docker-compose.yml に `$HOME` の追加マウントを足す案も
    検討したが、`/logs` の bind mount が既に LOG_DIR で per-run 切替可能
    だったため、scripts 側のデフォルト LOG_BASE を `$HOME/compass-bench-logs`
    に変えるだけで足りた。yaml/bind mount 構造はそのまま。
- 出力先解決は `scripts/lib/resolve_log_dir.sh` の `resolve_log_dir <tag> "${1:-}"`
  に集約。優先順位: 第1引数 > `BENCH_LOG_BASE` > `$HOME/compass-bench-logs`。
- LOG_DIR が repo 内に置かれた場合に備えて `.gitignore` の `logs_*/` は維持。
- 正本は `reports/report_*.md`。**手書き転記**で数値を残す。
  - 理由: Zenodoの公開データ・公開リポジトリでもhostnameや絶対パスが
    生artifactには混入する。レポートに転記する過程でこれらを除去する。
- セッションノートは `.claude-notes/YYYY-MM-DD-*.md`。

## コーディング規約

- Python: PEP 8、関数 snake_case、クラス PascalCase、定数 UPPER_SNAKE_CASE
- Docstring: Google Style、**英語**
- Bash: `set -u` (`set -e` は意図的に使わない場面もあるので個別判断)
- Makefile: 各ターゲットに `## 説明` を付け、`make help` で一覧化 (説明部分は英語)

## Git運用

- ブランチ戦略: `main` 直push可 (個人プロジェクト)。
  大きな変更は `feature/*` を切る。
- コミットメッセージ: 英文、動詞から始める。
- コミット署名: COMPASS本家のCLAUDE.md規約に揃え、以下を付与:
  ```
  🤖 Assisted by [Claude Opus 4.7](https://claude.ai/code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
  モデルが変わった場合は `[Claude Opus 4.7]` の部分を実際のモデル名に差し替える。

## 開発ガイドライン

### ドキュメント更新プロセス

機能追加やPhase完了時には、以下を同期更新する:

1. `compass-benchmark/CLAUDE.md`: 規約・実行モデルの変更
2. `compass-benchmark/README.md`: ユーザー向け使用方法
3. `compass-benchmark/Makefile`: `## コメント` (`make help` 表示)
4. `compass-benchmark/reports/`: 新しいベンチ結果を追記

### コミット粒度

- 1コミット = 1つの主要な変更
- 関連する変更は1つにまとめる
- 大きな変更は段階的に分割

### プレフィックスと絵文字 (本家COMPASSのCLAUDE.mdに準拠)

- ✨ feat: 新機能
- 🐞 fix: バグ修正
- 📚 docs: ドキュメント
- 🛠️ refactor: リファクタリング
- ⚡ perf: パフォーマンス改善
- ✅ test: テスト追加・修正
- 🏗️ chore: ビルド・補助ツール
- 📝 update: 更新・改善
