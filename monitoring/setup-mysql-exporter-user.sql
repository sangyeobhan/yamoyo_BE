-- mysqld_exporter 전용 읽기 전용 계정
-- EC2-A에서 실행: mysql -h <RDS endpoint> -u admin -p < setup-mysql-exporter-user.sql

CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'exporterPass2026';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;