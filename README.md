# Monitoring

MiniPG(PG-Server, Card-Server)의 지표를 수집하고 보여주는 모니터링 서버.
부하 테스트 시 애플리케이션 서버와 자원이 섞이지 않도록 별도로 운영한다.

## 구성
- Prometheus (9090): 5초마다 각 서버의 `/actuator/prometheus` 수집, 15일 보관
- Grafana (3000): Prometheus 데이터 소스와 `MiniPG Overview` 대시보드 자동 등록
- mysqld_exporter (9104: PG DB, 9105: 카드사 DB): MySQL 상태 지표를 Prometheus 형식으로 변환
- Loki (3100): 로그 저장소
- Alloy (12345): 앱의 JSON 로그 파일(`../PG-Server/logs`, `../Card-Server/logs`)을 읽어 Loki로 전송

## 로컬 실행
1. PG-Server(8080), Card-Server(8081)를 실행한다.
2. (처음 한 번) 각 MySQL에 exporter 계정 생성
   ```
   docker exec -i pg-mysql   mysql -uroot -proot < mysql/create-exporter-user.sql
   docker exec -i card-mysql mysql -uroot -proot < mysql/create-exporter-user.sql
   ```
3. `docker compose up -d`
4. Prometheus 수집 상태: http://localhost:9090/targets (pg-server, card-server, mysql 2개 모두 UP)
5. Grafana: http://localhost:3000 (admin / admin) → MiniPG 폴더 → MiniPG Overview

## AWS
Infra 레포(env)가 EC2를 만들 때 각 서버가 부팅하면서 이 레포를 받아 실행한다. 직접 실행할 일은 없다.

| 폴더 | 실행 위치 | 내용 |
|---|---|---|
| `aws/` | 모니터링 EC2 | Prometheus·Grafana·Loki. Grafana 비밀번호는 SSM 값을 환경 변수로 받음 |
| `agent/` | pg, pg-db, card EC2 | Alloy: 앱 로그 → Loki, 호스트 지표(CPU·메모리·디스크·네트워크) → Prometheus remote write |

- 수집 대상은 IP 대신 **EC2 태그로 자동 탐색**(`aws/prometheus.yml`, ec2_sd_configs)
  - `Role=pg` → pg-server(8080), `Role=card` → card-server(8081), `Db` 태그가 있는 서버 → mysqld_exporter(9104), `db` 라벨 = 태그 값
- 로그·호스트 지표에는 `host` 라벨(pg, pg-db, card)이 붙는다
- 이 레포는 public이므로 비밀번호·키·실제 IP를 커밋하지 않는다 (docker-compose.yml의 admin/exporter는 로컬 전용 값)

## 수집 대상 변경 (로컬)
`prometheus/prometheus.yml`의 `targets`를 바꾸고 다시 읽는다.
```
curl -X POST http://localhost:9090/-/reload
```

## 대시보드
| 영역 | 패널 |
|---|---|
| 비즈니스 | 승인 결과별 처리량, 승인 성공률, 결과 불명(REQUESTED) 거래 수, 취소 결과별 처리량, 만료 건수, 정산 소요 시간·처리 가맹점 |
| PG API | RPS, p95/p99, 상태 코드별 처리량, 5xx 에러율, Tomcat 스레드 |
| DB 커넥션 | active/idle/max, pending(대기 요청), 획득 시간, 점유 시간 |
| 카드사 | PG 기준 호출 p99, 카드사 기준 응답 p99, 호출 결과, 카드사 처리량 |
| JVM | 힙, GC 정지 시간, CPU, 스레드 수 |
| MySQL | QPS, 명령별 처리량, 연결 수(connected/running), 느린 쿼리, 행 락 대기 횟수·시간, 행 처리량, 버퍼 풀 적중률 |
| 애플리케이션 상세 | 커넥션 획득 실패, 상태별 스레드, GC 후 live data, 할당 속도, 에러/경고 로그, 커밋/롤백 |
| MySQL 상세 | history list length, 데드락, 쿼리별 평균 실행 시간·횟수(상위 10), 테이블별 I/O 대기 |
| 호스트 (AWS) | 서버별 CPU 사용률·steal, 메모리, 디스크 사용률·I/O, 네트워크 |

## mysqld_exporter 추가 수집 항목
- `--collect.info_schema.innodb_metrics`: history list length, 데드락 등 InnoDB 내부 카운터
- `--collect.perf_schema.eventsstatements`: 쿼리 유형(digest)별 실행 횟수·시간
- `--collect.perf_schema.tableiowaits`: 테이블별 I/O 대기

데드락 그래프가 비어 있으면 해당 카운터가 꺼져 있는 것이므로 MySQL에서 켠다.
```
SET GLOBAL innodb_monitor_enable = 'lock_deadlocks';
```

## 로그
- 앱은 `logs/*.log`에 JSON(logstash 형식)으로 기록하고, Alloy가 읽어 Loki로 보낸다. 콘솔 출력은 사람이 읽는 형식 그대로.
- 라벨은 `app`, `level`만 사용 (값 종류가 적은 것만 라벨로). requestId·paymentKey는 본문에서 검색.
- Grafana → Explore → Loki 예시
  - 요청 하나의 전체 흐름 (PG → 카드사까지 같은 requestId):
    `{app=~".+"} | json | requestId="응답 헤더 X-Request-Id 값"`
  - 결제 하나의 이력: `{app="PG-Server"} | json | paymentKey="pk_..."`
  - 카드사 응답 없음: `{app="PG-Server", level="WARN"} |= "결과 모름"`
- 앱을 먼저 한 번 실행해 `logs` 디렉터리가 생긴 뒤 `docker compose up -d`를 하는 것을 권장

