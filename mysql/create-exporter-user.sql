-- mysqld_exporter 전용 계정 (읽기 전용 모니터링 권한만)
-- PG DB와 카드사 DB에 각각 실행한다.
--   docker exec -i pg-mysql   mysql -uroot -proot < mysql/create-exporter-user.sql
--   docker exec -i card-mysql mysql -uroot -proot < mysql/create-exporter-user.sql

CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'exporter' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
