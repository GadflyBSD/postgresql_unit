DROP FUNCTION IF EXISTS func_verificate_card_number(VARCHAR);
DROP FUNCTION IF EXISTS logic_build_people(JSON);
DROP VIEW IF EXISTS base_dividion_view;
DROP VIEW IF EXISTS base_domicile_view;

DROP TABLE IF EXISTS base_dividion_province;
CREATE TABLE base_dividion_province(
	code INTEGER NOT NULL,
	name VARCHAR(20) NOT NULL,
	PRIMARY KEY (code)
);
COMMENT ON TABLE base_dividion_province IS '省级行政区划';
COMMENT ON COLUMN base_dividion_province.code IS '代码';
COMMENT ON COLUMN base_dividion_province.name IS '省级名称';

DROP TABLE IF EXISTS base_dividion_city;
CREATE TABLE base_dividion_city(
	code INTEGER NOT NULL,
	name VARCHAR(40) NOT NULL,
	"provinceCode" INTEGER NOT NULL,
	PRIMARY KEY (code)
);
COMMENT ON TABLE base_dividion_city IS '地市级行政区划';
COMMENT ON COLUMN base_dividion_city.code IS '代码';
COMMENT ON COLUMN base_dividion_city.name IS '地市级名称';
COMMENT ON COLUMN base_dividion_city."provinceCode" IS '省级代码';

DROP TABLE IF EXISTS base_dividion_area;
CREATE TABLE base_dividion_area(
	code INTEGER NOT NULL,
	name VARCHAR(60) NOT NULL,
	"cityCode" INTEGER NOT NULL,
	"provinceCode" INTEGER NOT NULL,
	PRIMARY KEY (code)
);
COMMENT ON TABLE base_dividion_area IS '区县级行政区划';
COMMENT ON COLUMN base_dividion_area.code IS '代码';
COMMENT ON COLUMN base_dividion_area.name IS '区县级名称';
COMMENT ON COLUMN base_dividion_area."cityCode" IS '地市级代码';
COMMENT ON COLUMN base_dividion_area."provinceCode" IS '省级代码';

DROP TABLE IF EXISTS base_dividion_street;
CREATE TABLE base_dividion_street(
	code INTEGER NOT NULL,
	name VARCHAR(100) NOT NULL,
	"areaCode" INTEGER NOT NULL,
	"cityCode" INTEGER NOT NULL,
	"provinceCode" INTEGER NOT NULL,
	PRIMARY KEY (code)
);
COMMENT ON TABLE base_dividion_street IS '乡镇、街道级行政区划';
COMMENT ON COLUMN base_dividion_street.code IS '代码';
COMMENT ON COLUMN base_dividion_street.name IS '乡镇、街道级名称';
COMMENT ON COLUMN base_dividion_street."areaCode" IS '区县级代码';
COMMENT ON COLUMN base_dividion_street."cityCode" IS '地市级代码';
COMMENT ON COLUMN base_dividion_street."provinceCode" IS '省级代码';

DROP TABLE IF EXISTS base_dividion_village;
CREATE TABLE base_dividion_village(
	code BIGINT NOT NULL,
	name VARCHAR(250) NOT NULL,
	"streetCode" INTEGER NOT NULL,
	"areaCode" INTEGER NOT NULL,
	"cityCode" INTEGER NOT NULL,
	"provinceCode" INTEGER NOT NULL,
	PRIMARY KEY (code)
);
COMMENT ON TABLE base_dividion_village IS '村级行政区划';
COMMENT ON COLUMN base_dividion_village.code IS '代码';
COMMENT ON COLUMN base_dividion_village.name IS '村级名称';
COMMENT ON COLUMN base_dividion_village."streetCode" IS '乡镇、街道级代码';
COMMENT ON COLUMN base_dividion_village."areaCode" IS '区县级代码';
COMMENT ON COLUMN base_dividion_village."cityCode" IS '地市级代码';
COMMENT ON COLUMN base_dividion_village."provinceCode" IS '省级代码';

DROP VIEW IF EXISTS base_dividion_view;
CREATE VIEW base_dividion_view AS
	SELECT
				 v.code,
				 v."provinceCode",
				 p.name AS province,
				 v."cityCode",
				 c.name AS city,
				 v."areaCode",
				 a.name AS area,
				 v."streetCode",
				 s.name AS street,
				 v.name AS village,
				 (CASE WHEN  (v."cityCode" IN (1101, 1201, 3101, 4190, 4290, 4690, 5001, 5002, 6590)) THEN
						 (p.name || a.name || s.name || v.name)
							 ELSE
						 (p.name || c.name || a.name || s.name || v.name)
						 END)AS address
	FROM
			 ((((base_dividion_village v LEFT JOIN base_dividion_province p ON v."provinceCode" = p.code)
					 LEFT JOIN base_dividion_city c ON v."cityCode" = c.code)
					 LEFT JOIN base_dividion_area a ON v."areaCode" = a.code)
					 LEFT JOIN base_dividion_street s ON v."streetCode" = s.code);
COMMENT ON VIEW base_dividion_view IS '中华人民共和国五级行政区划视图';
COMMENT ON COLUMN base_dividion_view.code IS '完整行政区划代码';
COMMENT ON COLUMN base_dividion_view."provinceCode" IS '省级代码';
COMMENT ON COLUMN base_dividion_view.province IS '省级名称';
COMMENT ON COLUMN base_dividion_view."cityCode" IS '地市级代码';
COMMENT ON COLUMN base_dividion_view.city IS '地市级名称';
COMMENT ON COLUMN base_dividion_view."areaCode" IS '区县级代码';
COMMENT ON COLUMN base_dividion_view.area IS '区县级名称';
COMMENT ON COLUMN base_dividion_view."streetCode" IS '乡镇、街道级代码';
COMMENT ON COLUMN base_dividion_view.street IS '乡镇、街道级名称';
COMMENT ON COLUMN base_dividion_view.village IS '村级名称';
COMMENT ON COLUMN base_dividion_view.address IS '详细地址';

DROP VIEW IF EXISTS base_domicile_view;
CREATE VIEW base_domicile_view AS
	SELECT
				 a.code,
				 a."provinceCode",
				 p.name AS province,
				 a."cityCode",
				 c.name AS city,
				 a.name AS area,
				 (CASE WHEN  (a."cityCode" IN (1101, 1201, 3101, 4190, 4290, 4690, 5001, 5002, 6590)) THEN
						 (p.name || '公安局' || a.name || '分局')
							 ELSE
						 (p.name || c.name || '公安局' || a.name || '分局')
						 END) AS domicile
	FROM
			 ((base_dividion_area a LEFT JOIN base_dividion_province p ON a."provinceCode" = p.code)
					 LEFT JOIN base_dividion_city c ON a."cityCode" = c.code);
COMMENT ON VIEW base_domicile_view IS '中华人民共和国三级行政区划视图';
COMMENT ON COLUMN base_domicile_view.code IS '完整行政区划代码';
COMMENT ON COLUMN base_domicile_view."provinceCode" IS '省级代码';
COMMENT ON COLUMN base_domicile_view.province IS '省级名称';
COMMENT ON COLUMN base_domicile_view."cityCode" IS '地市级代码';
COMMENT ON COLUMN base_domicile_view.city IS '地市级名称';
COMMENT ON COLUMN base_domicile_view.area IS '区县级名称';
COMMENT ON COLUMN base_domicile_view.domicile IS '户籍所在地';

DROP FUNCTION IF EXISTS func_is_leap_year(INTEGER);
CREATE OR REPLACE FUNCTION func_is_leap_year(IN year INTEGER) RETURNS BOOLEAN
AS $$
BEGIN
	IF((year % 4 = 0) AND (year % 100 != 0) OR (year % 400 = 0)) THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION func_is_leap_year(INTEGER) IS '判断给定参数所代表的年是否为闰年';

DROP FUNCTION IF EXISTS func_have_leap_year(INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION func_have_leap_year(IN start_year INTEGER, end_year INTEGER) RETURNS INTEGER
AS $$
DECLARE
	num INTEGER DEFAULT 0;
BEGIN
	IF (start_year < end_year) THEN
		FOR i IN start_year .. end_year LOOP
			IF(func_is_leap_year(i)) THEN
				num := num + 1;
			END IF;
		END LOOP;
	ELSEIF (start_year > end_year) THEN
		FOR i IN REVERSE start_year .. end_year LOOP
			IF(func_is_leap_year(i)) THEN
				num := num + 1;
			END IF;
		END LOOP;
	ELSE
		IF(func_is_leap_year(start_year)) THEN
			num := 1;
		END IF;
	END IF;
	RETURN num;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION func_have_leap_year(INTEGER, INTEGER) IS '判断给定参数所代表的年范围里面有多少个闰年';

DROP FUNCTION IF EXISTS func_verificate_card_number(VARCHAR);
CREATE OR REPLACE FUNCTION func_verificate_card_number(IN card VARCHAR) RETURNS JSON
AS $$
DECLARE
	w_key INTEGER[] DEFAULT ARRAY[7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
	c_key VARCHAR(1)[] DEFAULT ARRAY['1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'];
	sum INTEGER DEFAULT 0;
	last_key VARCHAR;
	police VARCHAR;
	province_name VARCHAR;
	city_name VARCHAR;
	area_name VARCHAR;
BEGIN
	FOR i IN 1 .. 17 LOOP
		sum := sum + substr(card, i, 1)::INTEGER * w_key[i];
	END LOOP;
	last_key := c_key[sum % 11 + 1];
	SELECT domicile, province, city, area INTO police, province_name, city_name, area_name FROM base_domicile_view WHERE code = substr(card, 1, 6)::INTEGER;
	RETURN json_build_object(
			'type', CASE WHEN (substr(card, 18, 1) =  last_key) THEN 'Success' ELSE 'Error' END,
			'card', CASE WHEN (length(card) = 17) THEN card || last_key ELSE substr(card, 1, 17) || last_key END,
			'police', police,
			'province', province_name,
			'city', city_name,
			'area', area_name,
			'message', CASE WHEN (substr(card::varchar, 18, 1) =  last_key) THEN '身份证校验成功！' ELSE '身份证校验失败！' END
	) ;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION func_verificate_card_number(VARCHAR) IS '身份证号码校验自定义函数';

DROP FUNCTION IF EXISTS func_random_percent(JSON);
CREATE OR REPLACE FUNCTION func_random_percent(IN percents JSON) RETURNS JSON
AS $$
DECLARE
	random RECORD;
BEGIN
	WITH CTE AS (SELECT random() * (SELECT SUM(x.percent) FROM json_to_recordset(percents) as x(percent INTEGER)) R)
	SELECT * INTO random
	FROM (
			 SELECT xx.id, SUM(xx.percent) OVER (ORDER BY xx.id) S, R, xx.label
			 FROM json_to_recordset(percents) as xx(id INTEGER, percent INTEGER, label VARCHAR) CROSS JOIN CTE
			 ) Q
	WHERE S >= R ORDER BY id LIMIT 1;
	RETURN json_build_object('id', random.id, 's', random.S, 'r', random.R, 'label', random.label);
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION func_random_percent(JSON) IS '随机概率自定义函数';

DROP FUNCTION IF EXISTS logic_build_people(JSON);
CREATE OR REPLACE FUNCTION logic_build_people(IN people JSON) RETURNS JSON
AS $$
DECLARE
	min_age INTEGER DEFAULT 18;
	max_age INTEGER DEFAULT 65;
	genders JSON DEFAULT json_build_array(
			json_build_object('id', 0, 'percent', 8, 'label', '女'), json_build_object('id', 1, 'percent', 12, 'label', '男'), json_build_object('id', 2, 'percent', 8, 'label', '女'),
			json_build_object('id', 3, 'percent', 12, 'label', '男'), json_build_object('id', 4, 'percent', 8, 'label', '女'), json_build_object('id', 5, 'percent', 12, 'label', '男'),
			json_build_object('id', 6, 'percent', 8, 'label', '女'), json_build_object('id', 7, 'percent', 12, 'label', '男'), json_build_object('id', 8, 'percent', 8, 'label', '女'),
			json_build_object('id', 9, 'percent', 12, 'label', '男')
	);
	nations JSON DEFAULT json_build_array(
			json_build_object('id', 0, 'percent', 30, 'label', '汉族'), json_build_object('id', 0, 'percent', 3, 'label', '满族'), json_build_object('id', 0, 'percent', 3, 'label', '蒙古族'),
			json_build_object('id', 0, 'percent', 5, 'label', '回族'), json_build_object('id', 0, 'percent', 2, 'label', '藏族'), json_build_object('id', 0, 'percent', 2, 'label', '维吾尔族'),
			json_build_object('id', 0, 'percent', 2, 'label', '苗族'), json_build_object('id', 0, 'percent', 2, 'label', '彝族'), json_build_object('id', 0, 'percent', 2, 'label', '壮族'),
			json_build_object('id', 0, 'percent', 1, 'label', '布依族'), json_build_object('id', 0, 'percent', 1, 'label', '侗族'), json_build_object('id', 0, 'percent', 1, 'label', '瑶族'),
			json_build_object('id', 0, 'percent', 2, 'label', '白族'), json_build_object('id', 0, 'percent', 1, 'label', '土家族'), json_build_object('id', 0, 'percent', 1, 'label', '哈尼族'),
			json_build_object('id', 0, 'percent', 1, 'label', '哈萨克族'), json_build_object('id', 0, 'percent', 2, 'label', '傣族'), json_build_object('id', 0, 'percent', 1, 'label', '黎族'),
			json_build_object('id', 0, 'percent', 1, 'label', '傈僳族'), json_build_object('id', 0, 'percent', 2, 'label', '佤族'), json_build_object('id', 0, 'percent', 1, 'label', '畲族'),
			json_build_object('id', 0, 'percent', 1, 'label', '高山族'), json_build_object('id', 0, 'percent', 1, 'label', '拉祜族'), json_build_object('id', 0, 'percent', 1, 'label', '水族'),
			json_build_object('id', 0, 'percent', 1, 'label', '东乡族'), json_build_object('id', 0, 'percent', 1, 'label', '纳西族'), json_build_object('id', 0, 'percent', 1, 'label', '景颇族'),
			json_build_object('id', 0, 'percent', 1, 'label', '柯尔克孜族'), json_build_object('id', 0, 'percent', 1, 'label', '土族'), json_build_object('id', 0, 'percent', 1, 'label', '达斡尔族'),
			json_build_object('id', 0, 'percent', 1, 'label', '仫佬族'), json_build_object('id', 0, 'percent', 1, 'label', '羌族'), json_build_object('id', 0, 'percent', 1, 'label', '布朗族'),
			json_build_object('id', 0, 'percent', 1, 'label', '撒拉族'), json_build_object('id', 0, 'percent', 1, 'label', '毛南族'), json_build_object('id', 0, 'percent', 1, 'label', '仡佬族'),
			json_build_object('id', 0, 'percent', 1, 'label', '锡伯族'), json_build_object('id', 0, 'percent', 1, 'label', '阿昌族'), json_build_object('id', 0, 'percent', 1, 'label', '普米族'),
			json_build_object('id', 0, 'percent', 1, 'label', '朝鲜族'), json_build_object('id', 0, 'percent', 1, 'label', '塔吉克族'), json_build_object('id', 0, 'percent', 1, 'label', '怒族'),
			json_build_object('id', 0, 'percent', 1, 'label', '乌孜别克族'), json_build_object('id', 0, 'percent', 1, 'label', '俄罗斯族'), json_build_object('id', 0, 'percent', 1, 'label', '鄂温克族'),
			json_build_object('id', 0, 'percent', 1, 'label', '德昂族'), json_build_object('id', 0, 'percent', 1, 'label', '保安族'), json_build_object('id', 0, 'percent', 1, 'label', '裕固族'),
			json_build_object('id', 0, 'percent', 1, 'label', '京族'), json_build_object('id', 0, 'percent', 1, 'label', '塔塔尔族'), json_build_object('id', 0, 'percent', 1, 'label', '独龙族'),
			json_build_object('id', 0, 'percent', 1, 'label', '鄂伦春族'), json_build_object('id', 0, 'percent', 1, 'label', '赫哲族'), json_build_object('id', 0, 'percent', 1, 'label', '门巴族'),
			json_build_object('id', 0, 'percent', 1, 'label', '珞巴族'), json_build_object('id', 0, 'percent', 1, 'label', '基诺族')
	);
	random JSON;
	feature VARCHAR[];
	min_date INTEGER;
	max_date INTEGER;
	last_day INTEGER;
	default_age INTEGER DEFAULT NULL;
	default_year INTEGER DEFAULT NULL;
	default_month INTEGER DEFAULT NULL;
	default_day INTEGER DEFAULT NULL;
	default_dividion INTEGER DEFAULT NULL;
	nation VARCHAR(20);
	face VARCHAR(20);
	birthday DATE;
	stree INTEGER;
	dividion INTEGER;
	verificate JSON;
	gender INTEGER;
	height INTEGER;
	weight INTEGER;
BEGIN
	IF (json_extract_path_text(people, 'min_age') IS NOT NULL) THEN
		min_age := json_extract_path_text(people, 'min_age');
	END IF;
	IF (json_extract_path_text(people, 'max_age') IS NOT NULL) THEN
		max_age := json_extract_path_text(people, 'max_age');
	END IF;
	IF (json_extract_path_text(people, 'age') IS NOT NULL) THEN
		default_age := json_extract_path_text(people, 'age');
	END IF;
	IF (json_extract_path_text(people, 'year') IS NOT NULL) THEN
		default_year := json_extract_path_text(people, 'year');
	END IF;
	IF (json_extract_path_text(people, 'month') IS NOT NULL) THEN
		default_month := json_extract_path_text(people, 'month');
	END IF;
	IF (json_extract_path_text(people, 'day') IS NOT NULL) THEN
		default_day := json_extract_path_text(people, 'day');
	END IF;
	IF (json_extract_path_text(people, 'dividion') IS NOT NULL) THEN
		default_dividion := json_extract_path_text(people, 'dividion');
	END IF;
	IF (default_year IS NOT NULL AND default_month IS NOT NULL AND default_day IS NOT NULL) THEN
		-- 指定年月日
		birthday := (default_year || '-' || default_month || '-' || default_day)::DATE;
	ELSE
		CASE
			WHEN (default_age IS NOT NULL) THEN
			-- 指定岁数
			min_date := 365 * default_age +  func_have_leap_year((date_part('year', CURRENT_DATE) - default_age)::INTEGER, date_part('year', CURRENT_DATE)::INTEGER);
			max_date := 365 * (default_age + 1) +  func_have_leap_year((date_part('year', CURRENT_DATE) - default_age + 1)::INTEGER, date_part('year', CURRENT_DATE)::INTEGER);
			WHEN (default_year IS NOT NULL AND default_month IS NULL) THEN
			-- 指定年
			min_date := CURRENT_DATE - ((date_part('year', CURRENT_DATE) - (date_part('year', CURRENT_DATE) - default_year)) || '-1-1')::DATE;
			max_date := CURRENT_DATE - ((date_part('year', CURRENT_DATE) - (date_part('year', CURRENT_DATE) - default_year)) || '-12-31')::DATE;
			WHEN (default_year IS NOT NULL AND default_month IS NOT NULL AND default_day IS NULL) THEN
			-- 指定年和月
			IF (default_month = 2 AND func_is_leap_year(default_year) IS TRUE) THEN
				last_day := 28;
			ELSEIF (default_month = 2 AND func_is_leap_year(default_year) IS FALSE) THEN
				last_day := 29;
			ELSE
				IF (default_month IN (4, 6, 9, 11)) THEN
					last_day := 30;
				ELSE
					last_day := 31;
				END IF;
			END IF;
			min_date := CURRENT_DATE - (default_year || '-' || default_month || '-1')::DATE;
			max_date := CURRENT_DATE - (default_year || '-' || default_month || '-' || last_day)::DATE;
			WHEN (default_year IS NULL AND default_month IS NOT NULL AND default_day IS NOT NULL) THEN
			-- 指定月和日
			min_date := CURRENT_DATE - ((date_part('year', CURRENT_DATE) - (date_part('year', CURRENT_DATE) - min_age)) || '-' || default_month || '-' || default_day)::DATE;
			max_date := CURRENT_DATE - ((date_part('year', CURRENT_DATE) - (date_part('year', CURRENT_DATE) - max_age)) || '-' || default_month || '-' || default_day)::DATE;
		ELSE
			-- 什么都没有指定（仅指定日无效）
			min_date := 365 * min_age +  func_have_leap_year((date_part('year', CURRENT_DATE) - min_age)::INTEGER, date_part('year', CURRENT_DATE)::INTEGER);
			max_date := 365 * max_age + 1 +  func_have_leap_year((date_part('year', CURRENT_DATE) - max_age + 1)::INTEGER, date_part('year', CURRENT_DATE)::INTEGER);
		END CASE;
		birthday := CURRENT_DATE - floor(random() * (max_date - min_date + 1) + min_date)::INTEGER;
	END IF;
	IF (json_extract_path_text(people, 'gender') IS NOT NULL) THEN
		gender := json_extract_path_text(people, 'gender');
	ELSE
		random := func_random_percent(genders);
		gender := json_extract_path_text(random, 'id');
	END IF;
	IF (json_extract_path_text(people, 'nation') IS NOT NULL) THEN
		nation := json_extract_path_text(people, 'nation');
	ELSE
		random := func_random_percent(nations);
		nation := json_extract_path_text(random, 'label');
	END IF;
	IF (json_extract_path_text(people, 'height') IS NOT NULL) THEN
		height := json_extract_path_text(people, 'height');
	ELSE
		IF (gender % 2 = 1) THEN
			height := floor(random() * (195-155+1)+155);
		ELSE
			height := floor(random() * (180-145+1)+145);
		END IF;
	END IF;
	IF (json_extract_path_text(people, 'weight') IS NOT NULL) THEN
		weight := json_extract_path_text(people, 'weight');
	ELSE
		IF (gender % 2 = 1) THEN
			weight := floor(random() * (120-60+1)+60);
		ELSE
			weight := floor(random() * (100-45+1)+45);
		END IF;
	END IF;
	IF (gender % 2 = 1) THEN
		IF(height >= 180) THEN
			feature := array['高个子'];
		ELSEIF (height <= 160) THEN
			feature := array['矮个子'];
		ELSE
			feature := array['一般身高'];
		END IF;
		IF(height >= 80) THEN
			feature := array_append(feature, '胖');
		ELSEIF (height =< 65) THEN
			feature := array_append(feature, '瘦');
		ELSE
			feature := array_append(feature, '身材匀称');
		END IF;
	ELSE
		IF(height >= 170) THEN
			feature := array['高个子'];
		ELSEIF (height <= 155) THEN
			feature := array['矮个子'];
		ELSE
			feature := array['一般身高'];
		END IF;
		IF(height >= 70) THEN
			feature := array_append(feature, '胖');
		ELSEIF (height =< 50) THEN
			feature := array_append(feature, '瘦');
		ELSE
			feature := array_append(feature, '身材匀称');
		END IF;
	END IF;
	IF (json_extract_path_text(people, 'feature') IS NOT NULL) THEN
		feature := array_append(feature, json_extract_path_text(people, 'feature'));
	ELSE
		IF (gender % 2 = 1) THEN
			CASE floor(random() * 11)
				WHEN 1, 2 THEN
					feature := array_append(feature, '光头');
				WHEN 3, 4 THEN
					feature := array_append(feature, '秃顶');
				WHEN 5, 6 THEN
					feature := array_append(feature, '染发');
				WHEN 7, 8 THEN
					feature := array_append(feature, '长发');
			ELSE
			END CASE;
		ELSE
			CASE floor(random() * 11)
				WHEN 1, 2 THEN
					feature := array_append(feature, '短发', '染发');
				WHEN 3, 4 THEN
					feature := array_append(feature, '短发');
				WHEN 5, 6 THEN
					feature := array_append(feature, '长发');
				WHEN 7, 8 THEN
					feature := array_append(feature, '长发', '染发');
			ELSE
			END CASE;
		END IF;
		CASE floor(random() * 11)
			WHEN 1 THEN
				feature := array_append(feature, '左手残疾');
			WHEN 3 THEN
				feature := array_append(feature, '左脚残疾');
			WHEN 5 THEN
				feature := array_append(feature, '左眼残疾');
			WHEN 4, 6, 7, 8 THEN
				feature := array_append(feature, '眼镜');
		ELSE
		END CASE;
		CASE floor(random() * 11)
			WHEN 1 THEN
				feature := array_append(feature, '右手残疾');
			WHEN 4 THEN
				feature := array_append(feature, '右脚残疾');
			WHEN 6 THEN
				feature := array_append(feature, '右眼残疾');
			WHEN 7, 8 THEN
				feature := array_append(feature, '口吃');
		ELSE
		END CASE;
	END IF;
	IF (json_extract_path_text(people, 'face') IS NOT NULL) THEN
		face := json_extract_path_text(people, 'face');
	ELSE
		CASE floor(random() * 9)
			WHEN 1 THEN
				face := '杏仁形脸型';
			WHEN 2 THEN
				face := '卵圆形脸型';
			WHEN 3 THEN
				face := '圆形脸型';
			WHEN 4 THEN
				face := '长圆形脸型';
			WHEN 5 THEN
				face := '方形脸型';
			WHEN 6 THEN
				face := '长方形脸型';
			WHEN 7 THEN
				face := '菱形脸型';
			WHEN 8 THEN
				face := '三角形脸型';
		ELSE
		END CASE;
	END IF;
	CASE
		WHEN (length(default_dividion::VARCHAR) >=2 AND length(default_dividion::VARCHAR) < 4) THEN
		SELECT code, "areaCode" INTO stree, dividion FROM base_dividion_street WHERE "provinceCode" = substr(default_dividion, 1, 2) ORDER BY random() LIMIT 1;
		WHEN (length(default_dividion::VARCHAR) >=4 AND length(default_dividion::VARCHAR) < 6) THEN
		SELECT code, "areaCode" INTO stree, dividion FROM base_dividion_street WHERE "cityCode" = substr(default_dividion, 1, 4) ORDER BY random() LIMIT 1;
		WHEN (length(default_dividion::VARCHAR) >=6) THEN
		SELECT code, "areaCode" INTO stree, dividion FROM base_dividion_street WHERE "areaCode" = substr(default_dividion, 1, 6) ORDER BY random() LIMIT 1;
	ELSE
		SELECT code, "areaCode" INTO stree, dividion FROM base_dividion_street ORDER BY random() LIMIT 1;
	END CASE;
	verificate := func_verificate_card_number(dividion || to_char(birthday, 'YYYYMMDD') || substr(stree::varchar, 8, 2) || gender);
	RETURN json_build_object(
			'birthday', birthday,
			'age', age(birthday),
			'gender', CASE WHEN(gender % 2 = 1) THEN '男' ELSE '女' END,
			'card', json_extract_path_text(verificate, 'card'),
			'nation', nation,
			'police', json_extract_path_text(verificate, 'police'),
			'province', json_extract_path_text(verificate, 'province'),
			'city', json_extract_path_text(verificate, 'city'),
			'area', json_extract_path_text(verificate, 'area'),
			'feature', array_to_json(feature),
			'face', face,
			'height', height,
			'weight', weight
	);
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION logic_build_people(JSON) IS '按需生成一个虚拟个人信息的操作';