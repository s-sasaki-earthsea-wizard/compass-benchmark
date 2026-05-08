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
make baseline LOG_DIR=logs_baseline_$(date +%Y%m%d)

# 5. プロファイル
make profile-pyspy    LOG_DIR=logs_pyspy_$(date +%Y%m%d)
make profile-cprofile LOG_DIR=logs_cprof_$(date +%Y%m%d)
```

各 `logs_*/` 以下に生のflamegraph/pstats/wall/RSSが落ち、
[reports/](reports/) 配下のmdファイルに数値を手書き転記して正本化する。

## ターゲットデータ

[Zenodo 7668411](https://zenodo.org/record/7668411) より:

- SAFE: `S1A_IW_SLC__1SDV_20221016T015043_20221016T015111_045461_056FC0_6681.zip`
- 軌道: `S1A_OPER_AUX_POEORB_OPOD_20221105T083813_V20221015T225942_20221017T005942.EOF`
- DEM: `test_dem.tiff`
- burst map: `test_burst_map.sqlite3`
- burst ID: `t064_135523_iw2`, 日付: `20221016`

## ライセンス

ベンチマークハーネスのコード自体はMIT。COMPASS本家のライセンスは[親リポジトリ](../LICENSE)を参照。
