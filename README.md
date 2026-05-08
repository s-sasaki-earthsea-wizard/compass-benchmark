# compass-benchmark

[opera-adt/COMPASS](https://github.com/opera-adt/COMPASS) のSAFE→CSLC化処理を
プロファイリングするためのベンチマーク・ハーネス。本リポジトリはCOMPASS本家の
fork **ではなく**、`opera-adt/COMPASS` の隣 (sibling) に置く独立リポジトリとして
管理することで、機械依存のbench artifactをCOMPASSの履歴に持ち込まないようにする。

物理的には `COMPASS/compass-benchmark/` にネストして配置するが、
`COMPASS/.git/info/exclude` で `/compass-benchmark/` を非追跡化しているため、
COMPASS本家側からは見えない。

## ディレクトリ構成

```
.
├── Makefile                       # `make help` でターゲット一覧
├── requirements.txt               # bench imageに入れるpipパッケージ群
├── docker/
│   ├── Dockerfile                 # FROM opera/cslc_s1:final_0.5.6 + bench tools
│   └── docker-compose.yml         # volume mounts, cap_add: SYS_PTRACE
├── scripts/
│   ├── build_image.sh             # ベース + bench派生 image を build
│   ├── prepare_data.sh            # Zenodo 7668411 を fixtures/data/ へ
│   ├── run_smoke.sh               # 配管確認 (短時間)
│   ├── run_baseline.sh            # E2E wall/RSS のみ
│   ├── run_profile_pyspy.sh       # py-spy flamegraph
│   ├── run_profile_cprofile.sh    # cProfile + pstats
│   └── lib/
│       ├── setup_ulimit.sh        # OOM safety net (RAM 80% で VA cap)
│       └── compose_run.sh         # docker compose run 共通ラッパー
├── tools/                         # Python utilities (Docker内で実行)
│   ├── render_runconfig.py        # template → runconfig
│   ├── parse_cprofile.py          # pstats → markdown summary
│   └── verify_output.py           # CSLC h5 の妥当性チェック
├── fixtures/
│   ├── geo_cslc_s1_template.yaml  # COMPASS/tests/data/ から派生
│   └── data/                      # Zenodo ダウンロード (gitignored)
├── reports/                       # ★正本: ベンチ結果の手書き転記
│   ├── report_baseline.md
│   ├── report_profile_pyspy.md
│   └── report_profile_cprofile.md
└── logs_*/                        # 各runの生artifact (gitignored)
```

## 前提

- ホスト: Linux + Docker + (任意で) docker-compose v2
- COMPASS本家リポジトリが親ディレクトリに存在 (`../docker/Dockerfile` を参照するため)
- 約20GBの空きディスク (Dockerイメージ + Zenodoデータ + logs)

## クイックスタート

```bash
# 1. ベースイメージ + bench派生イメージ build (初回のみ、~30分)
make build

# 2. Zenodo 7668411 のテストデータをダウンロード
make prepare-data

# 3. 配管確認
make smoke

# 4. ベースライン (wall/RSSのみ)
make baseline

# 5. プロファイル
make profile-pyspy
make profile-cprofile
```

各runの生artifact (flamegraph/pstats/wall/RSS/CSLC h5など) は **デフォルトで
`$HOME/compass-bench-logs/logs_<tag>_<timestamp>/`** に書かれ、
[reports/](reports/) 配下のmdファイルに数値を手書き転記して正本化する。

## ログ出力先のポリシー

bench artifact は **デフォルトで `$HOME/compass-bench-logs/` 配下** に書く。
理由は以下:

- 本リポジトリは CIFS (SMB) でマウントされた NAS 上にある運用が想定されているが、
  py-spy の ptrace attach + signal traffic は CIFS の長時間 syscall (特に
  h5py の `_close_open_objects`) と競合し、`errno=103 (ECONNABORTED)` で
  クラッシュすることが確認されている (compass-benchmark issue #2)。
  ホストローカルな POSIX FS (ext4 等) に書けば再現しない。
- `/tmp` は systemd-tmpfiles により boot 時にクリアされる運用が標準的なため
  避ける。`$HOME` 配下なら永続性が確保される。
- 出力先を変える必要がある場合 (CI、別ディスク、共有マウント等) は以下で上書きできる:

  ```bash
  # base dir 全体を変える
  BENCH_LOG_BASE=/mnt/local-ssd/bench make profile-pyspy

  # 1 回限り、特定 run の絶対パスを直接渡す (1st arg)
  make profile-pyspy LOG_DIR=/path/to/logs_pyspy_001
  ```

優先順位: **`LOG_DIR` (1st arg) > `BENCH_LOG_BASE`/logs_<tag>_<ts> > `$HOME/compass-bench-logs/logs_<tag>_<ts>`**。

## ターゲットデータ

[Zenodo 7668411](https://zenodo.org/record/7668411) より:

- SAFE: `S1A_IW_SLC__1SDV_20221016T015043_20221016T015111_045461_056FC0_6681.zip`
- 軌道: `S1A_OPER_AUX_POEORB_OPOD_20221105T083813_V20221015T225942_20221017T005942.EOF`
- DEM: `test_dem.tiff`
- burst map: `test_burst_map.sqlite3`
- burst ID: `t064_135523_iw2`, 日付: `20221016`

## ライセンス

ベンチマークハーネスのコード自体はMIT。COMPASS本家のライセンスは[親リポジトリ](../LICENSE)を参照。
