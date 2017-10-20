####Tested in zabbix3.0.x with mariadb10.1.12
###set event_scheduler on
SET GLOBAL event_scheduler = ON;
###In prevent of database abnormally restart, please make sure to add "event_scheduler = ON" to mysql configure file my.cnf.
SELECT @@event_scheduler;

####drop bak table
DROP TABLE IF EXISTS history_uint_bak;
DROP TABLE IF EXISTS history_bak;
DROP TABLE IF EXISTS history_str_bak;
DROP TABLE IF EXISTS history_text_bak;
DROP TABLE IF EXISTS history_log_bak;
DROP TABLE IF EXISTS trends_bak;
DROP TABLE IF EXISTS trends_uint_bak;

####create table
CREATE TABLE `history_uint_bak` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` bigint(20) unsigned NOT NULL DEFAULT '0',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_uint_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


CREATE TABLE `history_text_bak` (
  `id` bigint(20) unsigned NOT NULL,
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` text NOT NULL,
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_text_1` (`itemid`,`clock`),
  KEY `history_text_0` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


CREATE TABLE `history_str_bak` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` varchar(255) NOT NULL DEFAULT '',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_str_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


CREATE TABLE `history_bak` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` double(16,4) NOT NULL DEFAULT '0.0000',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


CREATE TABLE `history_log_bak` (
  `id` bigint(20) unsigned NOT NULL,
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `timestamp` int(11) NOT NULL DEFAULT '0',
  `source` varchar(64) NOT NULL DEFAULT '',
  `severity` int(11) NOT NULL DEFAULT '0',
  `value` text NOT NULL,
  `logeventid` int(11) NOT NULL DEFAULT '0',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_log_1` (`itemid`,`clock`),
  KEY `history_log_0` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


CREATE TABLE `trends_uint_bak` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `num` int(11) NOT NULL DEFAULT '0',
  `value_min` bigint(20) unsigned NOT NULL DEFAULT '0',
  `value_avg` bigint(20) unsigned NOT NULL DEFAULT '0',
  `value_max` bigint(20) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


CREATE TABLE `trends_bak` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `num` int(11) NOT NULL DEFAULT '0',
  `value_min` double(16,4) NOT NULL DEFAULT '0.0000',
  `value_avg` double(16,4) NOT NULL DEFAULT '0.0000',
  `value_max` double(16,4) NOT NULL DEFAULT '0.0000',
  PRIMARY KEY (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
/*!50100 PARTITION BY RANGE ( clock)
(PARTITION p2017_08_16 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-17 00:00:00")) ENGINE = InnoDB,
 PARTITION p2017_08_17 VALUES LESS THAN (UNIX_TIMESTAMP("2017-08-18 00:00:00")) ENGINE = InnoDB) */;


####dump data
INSERT INTO history_uint_bak SELECT * FROM history_uint;
INSERT INTO history_bak SELECT * FROM history;
INSERT INTO history_str_bak SELECT * FROM history_str;
INSERT INTO history_text_bak SELECT * FROM history_text;
INSERT INTO history_log_bak SELECT * FROM history_log;
INSERT INTO trends_bak SELECT * FROM trends;
INSERT INTO trends_uint_bak SELECT * FROM trends_uint;

####drop old table
DROP TABLE trends;
DROP TABLE trends_uint;
DROP TABLE history_uint;
DROP TABLE history;
DROP TABLE history_str;
DROP TABLE history_text;
DROP TABLE history_log;

####rename new table
ALTER TABLE trends_bak RENAME trends;
ALTER TABLE trends_uint_bak RENAME trends_uint;
ALTER TABLE history_uint_bak RENAME history_uint;
ALTER TABLE history_bak RENAME history;
ALTER TABLE history_str_bak RENAME history_str;
ALTER TABLE history_text_bak RENAME history_text;
ALTER TABLE history_log_bak RENAME history_log;

CREATE TABLE `manage_partitions` (
  `tablename` VARCHAR(64) NOT NULL COMMENT 'Table name',
  `period` VARCHAR(64) NOT NULL COMMENT 'Period - daily or monthly',
  `keep_history` INT(3) UNSIGNED NOT NULL DEFAULT '1' COMMENT 'For how many days or months to keep the partitions',
  `last_updated` DATETIME DEFAULT NULL COMMENT 'When a partition was added last time',
  `comments` VARCHAR(128) DEFAULT '1' COMMENT 'Comments',
  PRIMARY KEY (`tablename`)
) ENGINE=INNODB;

INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history', 'day', 30, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_uint', 'day', 30, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_str', 'day', 30, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_text', 'day', 30, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_log', 'day', 30, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('trends', 'month', 24, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('trends_uint', 'month', 24, now(), '');

DELIMITER $$
USE `zabbix`$$
DROP PROCEDURE IF EXISTS `create_next_partitions`$$
CREATE PROCEDURE `create_next_partitions`(IN_SCHEMANAME VARCHAR(64))
BEGIN
    DECLARE TABLENAME_TMP VARCHAR(64);
    DECLARE PERIOD_TMP VARCHAR(12);
    DECLARE DONE INT DEFAULT 0;

    DECLARE get_prt_tables CURSOR FOR
        SELECT `tablename`, `period`
            FROM manage_partitions;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN get_prt_tables;

    loop_create_part: LOOP
        IF DONE THEN
            LEAVE loop_create_part;
        END IF;

        FETCH get_prt_tables INTO TABLENAME_TMP, PERIOD_TMP;

        CASE WHEN PERIOD_TMP = 'day' THEN
                    CALL `create_partition_by_day`(IN_SCHEMANAME, TABLENAME_TMP);
             WHEN PERIOD_TMP = 'month' THEN
                    CALL `create_partition_by_month`(IN_SCHEMANAME, TABLENAME_TMP);
             ELSE
            BEGIN
                            ITERATE loop_create_part;
            END;
        END CASE;

                UPDATE manage_partitions set last_updated = NOW() WHERE tablename = TABLENAME_TMP;
    END LOOP loop_create_part;

    CLOSE get_prt_tables;
END$$
DELIMITER ;

DELIMITER $$
USE `zabbix`$$
DROP PROCEDURE IF EXISTS `create_partition_by_day`$$
CREATE PROCEDURE `create_partition_by_day`(IN_SCHEMANAME VARCHAR(64), IN_TABLENAME VARCHAR(64))
BEGIN
    DECLARE ROWS_CNT INT UNSIGNED;
    DECLARE BEGINTIME TIMESTAMP;
        DECLARE ENDTIME INT UNSIGNED;
        DECLARE PARTITIONNAME VARCHAR(16);
        SET BEGINTIME = DATE(NOW()) + INTERVAL 1 DAY;
        SET PARTITIONNAME = DATE_FORMAT( BEGINTIME, 'p%Y_%m_%d' );

        SET ENDTIME = UNIX_TIMESTAMP(BEGINTIME + INTERVAL 1 DAY);

        SELECT COUNT(*) INTO ROWS_CNT
                FROM information_schema.partitions
                WHERE table_schema = IN_SCHEMANAME AND table_name = IN_TABLENAME AND partition_name = PARTITIONNAME;

    IF ROWS_CNT = 0 THEN
                     SET @SQL = CONCAT( 'ALTER TABLE `', IN_SCHEMANAME, '`.`', IN_TABLENAME, '`',
                                ' ADD PARTITION (PARTITION ', PARTITIONNAME, ' VALUES LESS THAN (', ENDTIME, '));' );
                PREPARE STMT FROM @SQL;
                EXECUTE STMT;
                DEALLOCATE PREPARE STMT;
        ELSE
        SELECT CONCAT("partition `", PARTITIONNAME, "` for table `",IN_SCHEMANAME, ".", IN_TABLENAME, "` already exists") AS result;
        END IF;
END$$
DELIMITER ;

DELIMITER $$
USE `zabbix`$$
DROP PROCEDURE IF EXISTS `create_partition_by_month`$$
CREATE PROCEDURE `create_partition_by_month`(IN_SCHEMANAME VARCHAR(64), IN_TABLENAME VARCHAR(64))
BEGIN
    DECLARE ROWS_CNT INT UNSIGNED;
    DECLARE BEGINTIME TIMESTAMP;
        DECLARE ENDTIME INT UNSIGNED;
        DECLARE PARTITIONNAME VARCHAR(16);
        SET BEGINTIME = DATE(NOW() - INTERVAL DAY(NOW()) DAY + INTERVAL 1 DAY + INTERVAL 1 MONTH);
        SET PARTITIONNAME = DATE_FORMAT( BEGINTIME, 'p%Y_%m' );

        SET ENDTIME = UNIX_TIMESTAMP(BEGINTIME + INTERVAL 1 MONTH);

        SELECT COUNT(*) INTO ROWS_CNT
                FROM information_schema.partitions
                WHERE table_schema = IN_SCHEMANAME AND table_name = IN_TABLENAME AND partition_name = PARTITIONNAME;

    IF ROWS_CNT = 0 THEN
                     SET @SQL = CONCAT( 'ALTER TABLE `', IN_SCHEMANAME, '`.`', IN_TABLENAME, '`',
                                ' ADD PARTITION (PARTITION ', PARTITIONNAME, ' VALUES LESS THAN (', ENDTIME, '));' );
                PREPARE STMT FROM @SQL;
                EXECUTE STMT;
                DEALLOCATE PREPARE STMT;
        ELSE
        SELECT CONCAT("partition `", PARTITIONNAME, "` for table `",IN_SCHEMANAME, ".", IN_TABLENAME, "` already exists") AS result;
        END IF;
END$$
DELIMITER ;

DELIMITER $$
USE `zabbix`$$
DROP PROCEDURE IF EXISTS `drop_partitions`$$
CREATE PROCEDURE `drop_partitions`(IN_SCHEMANAME VARCHAR(64))
BEGIN
    DECLARE TABLENAME_TMP VARCHAR(64);
    DECLARE PARTITIONNAME_TMP VARCHAR(64);
    DECLARE VALUES_LESS_TMP INT;
    DECLARE PERIOD_TMP VARCHAR(12);
    DECLARE KEEP_HISTORY_TMP INT;
    DECLARE KEEP_HISTORY_BEFORE INT;
    DECLARE DONE INT DEFAULT 0;
    DECLARE get_partitions CURSOR FOR
        SELECT p.`table_name`, p.`partition_name`, LTRIM(RTRIM(p.`partition_description`)), mp.`period`, mp.`keep_history`
            FROM information_schema.partitions p
            JOIN manage_partitions mp ON mp.tablename = p.table_name
            WHERE p.table_schema = IN_SCHEMANAME
            ORDER BY p.table_name, p.subpartition_ordinal_position;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN get_partitions;

    loop_check_prt: LOOP
        IF DONE THEN
            LEAVE loop_check_prt;
        END IF;

        FETCH get_partitions INTO TABLENAME_TMP, PARTITIONNAME_TMP, VALUES_LESS_TMP, PERIOD_TMP, KEEP_HISTORY_TMP;
        CASE WHEN PERIOD_TMP = 'day' THEN
                SET KEEP_HISTORY_BEFORE = UNIX_TIMESTAMP(DATE(NOW() - INTERVAL KEEP_HISTORY_TMP DAY));
             WHEN PERIOD_TMP = 'month' THEN
                SET KEEP_HISTORY_BEFORE = UNIX_TIMESTAMP(DATE(NOW() - INTERVAL KEEP_HISTORY_TMP MONTH - INTERVAL DAY(NOW())-1 DAY));
             ELSE
            BEGIN
                ITERATE loop_check_prt;
            END;
        END CASE;

        IF KEEP_HISTORY_BEFORE >= VALUES_LESS_TMP THEN
                CALL drop_old_partition(IN_SCHEMANAME, TABLENAME_TMP, PARTITIONNAME_TMP);
        END IF;
        END LOOP loop_check_prt;

        CLOSE get_partitions;
END$$
DELIMITER ;

DELIMITER $$
USE `zabbix`$$
DROP PROCEDURE IF EXISTS `drop_old_partition`$$
CREATE PROCEDURE `drop_old_partition`(IN_SCHEMANAME VARCHAR(64), IN_TABLENAME VARCHAR(64), IN_PARTITIONNAME VARCHAR(64))
BEGIN
    DECLARE ROWS_CNT INT UNSIGNED;

        SELECT COUNT(*) INTO ROWS_CNT
                FROM information_schema.partitions
                WHERE table_schema = IN_SCHEMANAME AND table_name = IN_TABLENAME AND partition_name = IN_PARTITIONNAME;

    IF ROWS_CNT = 1 THEN
                     SET @SQL = CONCAT( 'ALTER TABLE `', IN_SCHEMANAME, '`.`', IN_TABLENAME, '`',
                                ' DROP PARTITION ', IN_PARTITIONNAME, ';' );
                PREPARE STMT FROM @SQL;
                EXECUTE STMT;
                DEALLOCATE PREPARE STMT;
        ELSE
        SELECT CONCAT("partition `", IN_PARTITIONNAME, "` for table `", IN_SCHEMANAME, ".", IN_TABLENAME, "` not exists") AS result;
        END IF;
END$$
DELIMITER ;

DELIMITER $$
USE `zabbix`$$
CREATE EVENT IF NOT EXISTS `e_part_manage`
       ON SCHEDULE EVERY 1 DAY
       STARTS '2017-08-17 00:00:00'
       ON COMPLETION PRESERVE
       ENABLE
       COMMENT 'Creating and dropping partitions'
       DO BEGIN
            CALL zabbix.drop_partitions('zabbix');
            CALL zabbix.create_next_partitions('zabbix');
       END$$
DELIMITER ;
