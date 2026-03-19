# H10 Hip Exoskeleton Encoding Pipeline

H10 고관절 외골격 실험의 데이터 인코딩 파이프라인.
K5 대사 측정, EMG 근전도, Visual3D 역동역학 데이터를 통합 처리한다.

## Experiment Overview

이변량 연속 프로토콜(bivariate continuous protocol)을 이용하여 고관절 외골격의 보조 전략을 시간 효율적으로 평가하는 연구이다. 기존 이산 프로토콜(9개 조건 × 5분 정상상태 측정)과 연속 프로토콜(시간 가변 토크 sweep + Instantaneous Cost Mapping)을 비교하여, 굴곡/신전 피크 보조 토크가 대사 소모율·보행 역학·근활성도에 미치는 영향을 1.5 m/s 트레드밀 보행에서 평가한다.

### Equipment

| 장비 | 모델 | 측정 | 샘플링 |
|------|------|------|--------|
| 고관절 외골격 | H10 (Angel Robotics), 3.4 kg, 200W DC, 18.75:1 | 보조 토크 (flx/ext) | — |
| 대사 분석기 | K5 (COSMED) | Breath-by-breath VO₂/VCO₂ | per breath |
| 지면반력계 | FP6012 (Bertec) ×2, 트레드밀 내장 | 지면반력 (GRF) | 500 Hz |
| 모션 캡처 | MX T-40 (Vicon) ×13, 16 마커 | 하지 관절 운동학 | 100 Hz |
| 근전도 | Trigno (Delsys), 무선 표면 EMG | 9 근육 (우측 하지) | 2000 Hz |

EMG 9 근육: VM, VL, RF, BF, ST, TA, GL, GM, SOL

### Participants

- **총 20명** (S005–S032), 건강 남성
- **파일럿 5명** (S005, S006, S008, S009, S010) — 토크 타이밍이 상이하여 본분석에서 제외
- **본분석 15명** (S017–S032): 22.9 ± 1.4세, 172.2 ± 4.9 cm, 68.8 ± 4.6 kg
- IRB: KAIST KH2024-270

### Protocol

**Multi-Day Schedule**

```
Day 1 (훈련)              Day 2                    Day 3
───────────────      ───────────────────      ───────────────────
 외골격 적응 훈련       Protocol A or B           Protocol B or A
 + 연습 보행           (무작위 배정)              (무작위 배정)
```

**Discrete Protocol (이산)**

3×3 토크 격자, 각 시도 5분 보행 + 1분 기립. 정상상태 대사율은 마지막 2분 평균.

```
각 시도:  ┌─────┐     ┌─────┐     ┌─────┐
          │기립 │────▶│보행 │────▶│휴식 │──▶ ...
          │ 1분 │     │ 5분 │     │ 3분 │
          └─────┘     └─────┘     └─────┘
                       ▲
                       ramp-up 30 steps

토크 격자 (Nm/kg):
  flx\ext   0.04   0.11   0.18
  0.04       ●      ●      ●
  0.11       ●      ●      ●       9 조건 × 무작위 순서
  0.18       ●      ●      ●
```

**Continuous Protocol (연속)**

세 가지 sweep 길이 (무작위 순서). 토크가 매 걸음마다 선형 변화.

```
 7분:  ├─고정 1분─┤──sweep 5분──┤─고정 1분─┤  휴식 4분
12분:  ├─고정 1분─┤──sweep 10분─┤─고정 1분─┤  휴식 7분
17분:  ├─고정 1분─┤──sweep 15분─┤─고정 1분─┤  휴식 10분

토크 궤적 (flx, ext) 평면:
  ext ▲
  0.18│  ●───●───END       ● = 이산 격자점
      │  │       ↑         궤적: (0.11,0.11)에서 출발하여
  0.11│  ●  START→●        9개 격자점을 모두 통과한 뒤
      │  │       │         (0.04,0.18)에 도달
  0.04│  ●───●───●
      └──┴───┴───┴──▶ flx
      0.04 0.11 0.18

대사 추정: ICM 디콘볼루션 (τ = 41.78 s) + LOESS 평활
```

### Measured Variables

| 분류 | 변수 | 단위 |
|------|------|------|
| 대사 | 순 대사 소모율, 비보조 대비 변화율 | W/kg, % |
| 보행역학 | 관절 각도, 순 관절 모멘트, 생체 고관절 일률 (P_bio = P_net − P_exo) | deg, Nm/kg, W/kg |
| 근전도 | 정규화 EMG 포락선, 입각기/유각기 평균, 동시수축지수 (CCI) | %MVC |

### Data Coding (`h10_param.csv`)

| 코드 | 의미 | 예시 |
|------|------|------|
| `-1` | 비보조 자연 보행 (외골격 미착용) | walk1, walk9 |
| `0 0` | Transparent 모드 (외골격 착용, 토크 0) | walk2 |
| `flx ext` | 이산 조건 (Nm/kg) | `0.11 0.18` |
| `Xm` | 연속 sweep 길이 | `5m`, `10m`, `15m` |
| `null` | 해당 시도 없음 | — |

## Requirements

- **MATLAB** R2022b 이상
- **Toolboxes**: Statistics and Machine Learning Toolbox, Signal Processing Toolbox
- (선택) Visual3D — 역동역학 처리 시 필요

## Setup

1. 이 저장소를 클론한다:
   ```bash
   git clone <repo-url> h10-encoding
   ```

2. `h10_2024/setup_template.m`을 `h10_2024/setup.m`으로 복사한 후, 로컬 데이터 경로를 수정한다:
   ```bash
   cp h10_2024/setup_template.m h10_2024/setup.m
   # setup.m 내부의 data_path, v3d_path 를 로컬 환경에 맞게 수정
   ```
   `h10_2024/setup.m`은 `.gitignore`에 포함되어 있으므로 로컬 경로가 커밋되지 않는다.
   (루트의 `setup.m`은 `utils/` path 추가 전용으로, 별도 수정 없이 추적된다.)

3. MATLAB에서 `h10_2024/` 디렉토리로 이동한 뒤 `setup`을 실행한다.
   이 스크립트는 내부에서 루트 `setup.m`(utils path 추가)과 `config.m`(공유 상수)을 자동 호출한다.

## Data Directory Structure

`DATA_DIR` 환경 변수가 가리키는 데이터 폴더는 다음 구조를 따른다:

```
DATA_DIR/
├── k5/            # K5 대사 데이터 (*.xlsx)
│   ├── S017/
│   ├── S018/
│   └── ...
├── h10/           # H10 외골격 로그 (*.csv)
├── fp/            # 지면반력 (*.tdms)
│   ├── cal_mat_left.txt
│   └── cal_mat_right.txt
├── log/           # 실험 로그 (*.tdms)
├── emg/           # EMG 데이터
├── c3d/           # C3D 모션 캡처
├── c3d_v3d/       # Visual3D 처리 결과
└── export/        # 파이프라인 출력 (자동 생성)
```

## Pipeline Execution Order

| 순서 | 스크립트 | 설명 | 출력 |
|------|----------|------|------|
| 1 | `insane_check.m` | 데이터 파일 무결성 검증 | (콘솔 리포트) |
| 2 | `encode_all.m` | K5/FP/H10/Log 통합 인코딩 | `enc_rs.mat` |
| 3 | `k5_continuous_processing.m` | 연속 프로토콜 Koller 모형 적합 | `k5_cont_results.mat` |
| 4 | `emg_post_processing.m` | EMG 정규화 및 활성도 산출 | `emg_norm.mat` |
| 5 | `visual3d_result.m` | V3D 역동역학 결과 처리 | `idyn_summary.mat` |
| 6 | `inv_dyn_report.m` | 관절 토크/일률 분석 | (리포트) |
| 7 | `report_ee.m` / `h10_report.m` | 에너지 소모/외골격 결과 리포트 | (리포트) |

## Glossary

| 약어 | 의미 |
|------|------|
| `K5` | COSMED K5 호흡가스 분석기 (대사 측정) |
| `FP` | Force Plate (지면반력계) |
| `H10` | H10 고관절 외골격 (연구용 프로토타입) |
| `V3D` | Visual3D (역동역학 소프트웨어) |
| `EMG` | 근전도 (Electromyography) |
| `ICM` | Instantaneous Cost Mapping (Koller et al. 2019) |
| `ee` | Energy Expenditure, 에너지 소모율 (W) |
| `disc` | Discrete protocol, 이산 프로토콜 (9점 격자) |
| `cont` | Continuous protocol, 연속 프로토콜 (5/10/15분) |
| `nat` / `non_exo` | 비보조 자연 보행 (외골격 미착용) |
| `trs` | Transparent mode (외골격 착용, 토크 0) |
| `SS` / `DS` | Single Support / Double Support (단각/양각 지지) |
| `BPM` | Beats Per Minute (보행 빈도) |
| `MVC` | Maximum Voluntary Contraction (최대 수의 수축) |

## Data Flow

```
Raw Data (K5/FP/H10/Log/EMG/C3D)
    │
    ├─ insane_check.m ──────────────────── (검증 리포트)
    ├─ post_log_process.m ─────────────── log_rs.mat (로그 캐시)
    │
    ├─ encode_all.m ───────────────────── enc_rs.mat
    │       │
    │       ├─ k5_continuous_processing.m ── k5_cont_results.mat
    │       ├─ report_ee.m ────────────── (EE 리포트 Figure)
    │       └─ h10_report.m ───────────── (H10 리포트 Figure)
    │
    ├─ emg_post_processing.m ──────────── emg_norm.mat
    │
    └─ visual3d_result.m ─────────────── idyn_summary.mat
            └─ inv_dyn_report.m ───────── (역동역학 분석)
```

## Key Struct: `enc_rs.mat`

`encode_all.m`이 생성하는 `rs` 구조체의 주요 필드:

| 필드 | 설명 |
|------|------|
| `rs.sub_info` | 참여자 정보 테이블 (ID, age, height, weight, 시도 인덱스) |
| `rs.param` | 프로토콜 파라미터 테이블 (시도별 토크 레벨) |
| `rs.pg_x`, `rs.pg_y` | 반응곡면 파라미터 격자 (141x141, Nm/kg) |
| `rs.<SubID>` | 참여자별 데이터 구조체 |
| `rs.<SubID>.walk<N>` | 시도별 결과 (ee_walk, ee_stand, h10, freq 등) |
| `rs.<SubID>.disc_p` | 이산 시도 파라미터 (9x2, Nm/kg) |
| `rs.<SubID>.disc_ee` | 이산 시도 EE (9x1, W) |
| `rs.<SubID>.nat_ee` | 자연 보행 EE (W) |
| `rs.cont_fit` | 풀링된 연속 프로토콜 ICM 적합 결과 |
| `rs.units` | 모든 필드의 단위 메타데이터 |

## Directory Layout

```
h10-encoding/
├── setup.m                    # utils/ MATLAB path 추가
├── h10_2024/
│   ├── setup_template.m       # 로컬 환경 설정 템플릿
│   ├── config.m               # 공유 상수 정의
│   ├── encode_all.m           # 메인 파이프라인
│   ├── k5_continuous_processing.m
│   ├── emg_post_processing.m
│   ├── visual3d_result.m
│   ├── inv_dyn_report.m
│   ├── h10_report.m
│   ├── insane_check.m
│   ├── multiple_dyn_get_offset.m
│   ├── report_ee.m
│   ├── post_log_process.m
│   ├── analyze_ci.m
│   ├── compare_ci_results.m
│   ├── h10_param.csv          # 프로토콜 파라미터
│   ├── sub_info.csv           # 피험자 정보
│   ├── k5_arrange.xlsx        # K5 시간 구간
│   ├── emg_scripts/           # EMG 서브 파이프라인
│   └── log_scripts/           # 로그 처리
└── utils/                     # 공용 유틸리티
    ├── ezc3d_matlab/          # C3D I/O (Windows 64-bit MEX)
    ├── IO/                    # 모션 파일 I/O
    ├── MatlabOpensimPipelineTools/
    └── Preprocessing/         # C3D 전처리
```

## License

This code is shared for research collaboration purposes.
