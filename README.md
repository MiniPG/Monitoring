# Monitoring

MiniPG(PG-Server, Card-Server)의 지표를 수집하고 보여주는 모니터링 서버.
부하 테스트 시 애플리케이션 서버와 자원이 섞이지 않도록 별도로 운영한다.

## 구성
- Prometheus (9090): 5초마다 각 서버의 `/actuator/prometheus` 수집, 15일 보관
- Grafana (3000): Prometheus 데이터 소스와 `MiniPG Overview` 대시보드 자동 등록
- mysqld_exporter (9104: PG DB, 9105: 카드사 DB): MySQL 상태 지표를 Prometheus 형식으로 변환

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

## 수집 대상 변경 (AWS 등)
`prometheus/prometheus.yml`의 `targets`를 서버 주소로 바꾸고 다시 읽는다.
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
