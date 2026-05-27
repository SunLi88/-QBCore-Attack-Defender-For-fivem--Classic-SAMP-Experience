-- Attack & Defend — Database Schema
-- Run this once on your server's database

CREATE TABLE IF NOT EXISTS `ad_stats` (
  `license`    varchar(60)  NOT NULL,
  `name`       varchar(100) NOT NULL DEFAULT '',
  `kills`      int(11)      NOT NULL DEFAULT 0,
  `deaths`     int(11)      NOT NULL DEFAULT 0,
  `wins`       int(11)      NOT NULL DEFAULT 0,
  `losses`     int(11)      NOT NULL DEFAULT 0,
  `matches`    int(11)      NOT NULL DEFAULT 0,
  `damage`     float        NOT NULL DEFAULT 0,
  `exp`        int(11)      NOT NULL DEFAULT 0,
  `last_team`  int(11)      NOT NULL DEFAULT 0,
  `updated_at` timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
