DROP FUNCTION IF EXISTS logic_lottery(INTEGER);
DROP VIEW IF EXISTS base_lottery_log_view;

/**
 # 奖项设置
```sql
INSERT INTO base_lottery (label, percent, totle) VALUES ('一等奖', 8.52, 2),('二等奖', 19.86, 5),('三等奖', 27.34, 10);
INSERT INTO base_lottery (label) VALUES ('鼓励奖');
```
 */
DROP TABLE IF EXISTS base_lottery;
CREATE TABLE base_lottery(
	id SERIAL,
	label VARCHAR(200) NOT NULL,
	percent NUMERIC(5, 2) NOT NULL,
	totle INTEGER DEFAULT 0,
	number INTEGER DEFAULT 0,
	amount INTEGER DEFAULT 0,
	initialize NUMERIC(4, 2),
	PRIMARY KEY (id)
);
COMMENT ON TABLE base_lottery IS '奖项设置信息表';
COMMENT ON COLUMN base_lottery.id IS '自增主键';
COMMENT ON COLUMN base_lottery.label IS '奖项名称';
COMMENT ON COLUMN base_lottery.percent IS '奖项当前获奖概率';
COMMENT ON COLUMN base_lottery.totle IS '奖项总数';
COMMENT ON COLUMN base_lottery.number IS '奖项当前时段总数';
COMMENT ON COLUMN base_lottery.amount IS '已奖获奖数量';
COMMENT ON COLUMN base_lottery.initialize IS '奖项初始化获奖概率';

CREATE OR REPLACE FUNCTION trigger_before_insert_base_lottery()
	RETURNS TRIGGER
AS $$
DECLARE
	percents NUMERIC(5, 2);
BEGIN
	IF (NEW.totle <> 0) THEN
		NEW.number := NEW.totle;
		NEW.initialize := NEW.percent;
	ELSE
		SELECT SUM(percent) INTO percents FROM base_lottery WHERE totle <> 0;
		NEW.percent := 100 - percents;
		NEW.initialize := NEW.percent;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS base_lottery_before_insert ON base_lottery;
CREATE TRIGGER base_lottery_before_insert BEFORE INSERT ON base_lottery
	FOR EACH ROW
EXECUTE PROCEDURE trigger_before_insert_base_lottery();

/**
 # 抽奖奖项时间分布信息
```sql
INSERT INTO base_lottery_distribute (lid, datetime, multiple, totle) VALUES
(1, '2018-10-23 16:30:00', 1.4, 1), (1, '2018-10-23 17:00:00', 1.2, 1);
INSERT INTO base_lottery_distribute (lid, datetime, percent, totle) VALUES
(2, '2018-10-23 16:30:00', 16.2, 3), (2, '2018-10-23 17:00:00', 18.1, 2);
INSERT INTO base_lottery_distribute (lid, datetime, percent, totle) VALUES
(3, '2018-10-23 16:30:00', 20.6, 4), (3, '2018-10-23 17:00:00', 19.5, 6);
```
 */
DROP TABLE IF EXISTS base_lottery_distribute;
CREATE TABLE base_lottery_distribute(
	id SERIAL,
	lid INTEGER NOT NULL,
	datetime TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
	percent NUMERIC(4, 2) DEFAULT 0,
	multiple NUMERIC(3, 2) DEFAULT NULL,
	totle INTEGER NOT NULL,
	PRIMARY KEY (id)
);
COMMENT ON TABLE base_lottery_distribute IS '抽奖奖项时间分布信息表';
COMMENT ON COLUMN base_lottery_distribute.id IS '自增主键';
COMMENT ON COLUMN base_lottery_distribute.lid IS '奖项ID';
COMMENT ON COLUMN base_lottery_distribute.datetime IS '设定时间段';
COMMENT ON COLUMN base_lottery_distribute.percent IS '当前时间段该奖项概率';
COMMENT ON COLUMN base_lottery_distribute.multiple IS '当前时间段该奖项概率倍率';
COMMENT ON COLUMN base_lottery_distribute.totle IS '当前时间段该奖项总数';

/**
 # 抽奖记录数据
 */
DROP TABLE IF EXISTS base_lottery_log;
CREATE TABLE base_lottery_log(
	id SERIAL,
	lid INTEGER DEFAULT 0,
	uid INTEGER NOT NULL UNIQUE,
	datetime TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (id)
);
COMMENT ON TABLE base_lottery_log IS '抽奖记录数据表';
COMMENT ON COLUMN base_lottery_log.id IS '自增主键';
COMMENT ON COLUMN base_lottery_log.lid IS '获奖奖项ID';
COMMENT ON COLUMN base_lottery_log.uid IS '获奖人uid';
COMMENT ON COLUMN base_lottery_log.datetime IS '抽奖时间';

/**
 # 抽奖获奖者记录视图
 */
DROP VIEW IF EXISTS base_lottery_log_view;
CREATE VIEW base_lottery_log_view AS
	SELECT
				 log.id,
				 log.uid,
				 lottery.id AS lottery_id,
				 lottery.label,
				 log.datetime
	FROM base_lottery_log log LEFT JOIN base_lottery lottery ON log.lid = lottery.id;
COMMENT ON VIEW base_lottery_log_view IS '抽奖记录视图';
COMMENT ON COLUMN base_lottery_log_view.id IS '自增主键';
COMMENT ON COLUMN base_lottery_log_view.uid IS '参与抽奖用户UID';
COMMENT ON COLUMN base_lottery_log_view.lottery_id IS '奖项ID';
COMMENT ON COLUMN base_lottery_log_view.label IS '获奖奖项名称';
COMMENT ON COLUMN base_lottery_log_view.datetime IS '获奖时间';

/**
 # 抽奖逻辑
 ```sql
 SELECT logic_lottery(floor(random() * 999999)::INTEGER);
 ```
 */
DROP FUNCTION IF EXISTS logic_lottery(INTEGER);
CREATE OR REPLACE FUNCTION logic_lottery(IN people INTEGER) RETURNS JSON
AS $$
DECLARE
	i INTEGER;
	numbers INTEGER;
	lottery RECORD;
	distribute RECORD;
	use_percent NUMERIC(5, 2);
	random RECORD;
	percents NUMERIC(5, 2);
	log_view JSON;
BEGIN
	set time zone 'PRC';
	SELECT SUM(percent) INTO use_percent FROM base_lottery WHERE totle <> 0;
	UPDATE base_lottery SET percent = (100 - use_percent) WHERE totle = 0;
	WITH CTE AS (SELECT random() * (SELECT SUM(x.percent) FROM base_lottery as x) R)
	SELECT * INTO random
	FROM (
			 SELECT xx.id, SUM(xx.percent) OVER (ORDER BY xx.id) S, R, xx.label
			 FROM base_lottery as xx CROSS JOIN CTE
			 ) Q
	WHERE S >= R ORDER BY id LIMIT 1;
	INSERT INTO base_lottery_log (lid, uid) VALUES (random.id, people);
	FOR lottery IN SELECT id, percent, totle, number, amount, initialize FROM base_lottery WHERE totle <> 0 LOOP
		SELECT count(*) INTO i FROM base_lottery_distribute WHERE datetime < NOW() AND lid = lottery.id;
		IF(i > 0) THEN
			SELECT percent, totle, multiple,
						 (SELECT SUM(totle) FROM base_lottery_distribute WHERE datetime < NOW() AND lid = lottery.id) AS sum
					INTO distribute
			FROM base_lottery_distribute WHERE datetime < NOW() AND lid = lottery.id ORDER BY datetime DESC LIMIT 1;
			IF (lottery.id = random.id) THEN
				numbers := distribute.sum - lottery.amount - 1;
			ELSE
				numbers := distribute.sum - lottery.amount;
			END IF;
			IF(distribute.multiple IS NULL) THEN
				percents := round(distribute.percent / distribute.totle * numbers, 2);
			ELSE
				percents := round(lottery.percent * distribute.multiple / distribute.totle * numbers, 2);
			END IF;
		ELSE
			numbers := lottery.number;
			percents := round(lottery.initialize / lottery.totle * numbers, 2);
		END IF;
		IF (lottery.id = random.id) THEN
			UPDATE base_lottery SET percent = percents, number = numbers, amount = (amount + 1) WHERE id = random.id;
		ELSE
			UPDATE base_lottery SET percent = percents, number = numbers WHERE id = lottery.id;
		END IF;
	END LOOP;
	SELECT json_agg(row_to_json(base_lottery_log_view)) INTO log_view FROM base_lottery_log_view WHERE uid = people;
	RETURN log_view;
	EXCEPTION WHEN OTHERS THEN
	RETURN json_build_object('type', 'Error', 'message', '抽奖失败!请不要重复抽奖', 'error', replace(SQLERRM, '"', '`'), 'sqlstate', SQLSTATE);
END;
$$ LANGUAGE plpgsql;