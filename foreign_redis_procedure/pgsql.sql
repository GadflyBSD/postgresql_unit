create extension if not exists "uuid-ossp";
create extension if not exists redis_fdw;
create extension if not exists pgcrypto ;
CREATE SERVER redis_server FOREIGN DATA WRAPPER redis_fdw OPTIONS (address '127.0.0.1', port '6379');
CREATE USER MAPPING FOR PUBLIC SERVER redis_server OPTIONS (password '');

DROP FUNCTION IF EXISTS structure_redis(JSON);
DROP TABLE IF EXISTS base_redis_foreigns;
DROP TYPE IF EXISTS methods;
DROP TYPE IF EXISTS redis_type;
DROP TYPE IF EXISTS redis_actions;

CREATE TYPE redis_type AS ENUM('list', 'info', 'custom');
CREATE TYPE methods AS ENUM('get', 'post', 'put', 'delete', 'options');
CREATE TYPE redis_actions AS ENUM('empty', 'remove', 'upsert', 'rebuild');

CREATE TABLE base_redis_foreigns (
	key VARCHAR(200) NOT NULL,
	foreigns VARCHAR(150) NOT NULL,
	schemas VARCHAR(100) NOT NULL,
	storage VARCHAR(100) NOT NULL,
	store VARCHAR(100) NOT NULL,
	"table" VARCHAR(150) DEFAULT NULL,
	"primary" VARCHAR(150) DEFAULT NULL,
	"where" VARCHAR(250) DEFAULT NULL,
	"data" JSON DEFAULT NULL,
	"type" redis_type DEFAULT 'list',
	dbindex SMALLINT DEFAULT 0,
	"method" methods DEFAULT 'get',
	"using" VARCHAR(100) DEFAULT NULL,
	"restful" VARCHAR(200) DEFAULT NULL,
	route JSON DEFAULT NULL,
	datetime TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT now(),
	PRIMARY KEY (key)
);
COMMENT ON TABLE base_redis_foreigns IS 'Redis外部表数据';
COMMENT ON COLUMN base_redis_foreigns.key IS 'Redis数据键名';
COMMENT ON COLUMN base_redis_foreigns.foreigns IS 'Redis外部表名';
COMMENT ON COLUMN base_redis_foreigns.schemas IS '前端模式名称';
COMMENT ON COLUMN base_redis_foreigns.storage IS '前端本地存储方式';
COMMENT ON COLUMN base_redis_foreigns.store IS '前端本地存储store名';
COMMENT ON COLUMN base_redis_foreigns.table IS '数据库查询表名';
COMMENT ON COLUMN base_redis_foreigns.primary IS '数据库主键列名';
COMMENT ON COLUMN base_redis_foreigns.where IS '数据库查询方法';
COMMENT ON COLUMN base_redis_foreigns.data IS '自定义缓存数据';
COMMENT ON COLUMN base_redis_foreigns.type IS '数据缓存类型';
COMMENT ON COLUMN base_redis_foreigns.dbindex IS 'Redis数据库id';
COMMENT ON COLUMN base_redis_foreigns.method IS '数据请求方式';
COMMENT ON COLUMN base_redis_foreigns.using IS '数据用途';
COMMENT ON COLUMN base_redis_foreigns.restful IS '数据请求RestFul路径';
COMMENT ON COLUMN base_redis_foreigns.route IS '数据请求Route方式参数';
COMMENT ON COLUMN base_redis_foreigns.datetime IS '最后更新时间';

/**
 # PostgreSQL redis操作存储过程
 */
CREATE OR REPLACE FUNCTION structure_redis(
	IN redis JSON
)RETURNS JSON
AS $$
DECLARE
	pk INTEGER;
	item RECORD;
	pk_val VARCHAR(100);
	key_val VARCHAR(150);
	schemas_val VARCHAR(50) DEFAULT 'app';
	storage_val VARCHAR(50) DEFAULT NULL;
	store_val VARCHAR(50) DEFAULT NULL;
	dbindex SMALLINT DEFAULT 0;
	table_val VARCHAR(100) DEFAULT NULL;
	primary_val VARCHAR(150) DEFAULT NULL;
	where_val	VARCHAR(250) DEFAULT NULL;
	custom_val JSON DEFAULT NULL;
	type_val redis_type DEFAULT 'list';
	method_val methods DEFAULT 'get';
	restful_val VARCHAR(200);
	route_val JSON DEFAULT NULL;
	data_val JSON DEFAULT NULL;
	redis_key VARCHAR(100);
	using_val VARCHAR(50) DEFAULT 'base';
	cache_val JSON;
	actions redis_actions DEFAULT 'upsert';
	foreign_table VARCHAR(100) DEFAULT NULL;
	foreign_table_array VARCHAR(100)[];
	foreign_table_num INTEGER;
	foreign_key_num INTEGER;
	redis_key_num INTEGER;
	foreign_num INTEGER;
	filed_array VARCHAR(50)[] := ARRAY[]::VARCHAR[];
	redisRecord RECORD;
	executesql TEXT;
BEGIN
	IF(json_extract_path_text(redis, 'table') IS NULL AND
	   json_extract_path_text(redis, 'data') IS NULL AND
	   json_extract_path_text(redis, 'action') IS NULL AND
	   json_extract_path_text(redis, 'key') IS NOT NULL
	) THEN
		actions := 'remove';
	ELSE
		IF (json_extract_path_text(redis, 'action') IS NOT NULL) THEN
			actions := json_extract_path_text(redis, 'action');
		END IF;
	END IF;
	IF (json_extract_path_text(redis, 'key') IS NOT NULL) THEN
		key_val := json_extract_path_text(redis, 'key');
		SELECT rec[1], rec[2],
		       (SELECT recd[1] FROM string_to_array(rec[3], ':') AS recd),
		       (SELECT recd[2] FROM string_to_array(rec[3], ':') AS recd)
				INTO schemas_val, storage_val, store_val, pk_val
		FROM string_to_array(key_val, '_') AS rec;
	ELSE
		IF (json_extract_path_text(redis, 'schemas') IS NOT NULL) THEN
			schemas_val := json_extract_path_text(redis, 'schemas');
		ELSE
			IF (actions = 'empty') THEN
				schemas_val := 'all';
			END IF;
		END IF;
		IF (json_extract_path_text(redis, 'storage') IS NOT NULL) THEN
			storage_val := json_extract_path_text(redis, 'storage');
		END IF;
		IF (json_extract_path_text(redis, 'store') IS NOT NULL) THEN
			store_val := json_extract_path_text(redis, 'store');
		END IF;
		IF (json_extract_path_text(redis, 'pk') IS NOT NULL) THEN
			pk_val := json_extract_path_text(redis, 'pk');
		END IF;
	END IF;
	IF (storage_val IS NULL AND actions = 'upsert') THEN
		RETURN json_build_object('type', 'Error', 'message', '新增或更新Redis缓存时storage参数不能为空!', 'code', 230);
	END IF;
	IF (store_val IS NULL AND actions = 'upsert') THEN
		RETURN json_build_object('type', 'Error', 'message', '新增或更新Redis缓存时store参数不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(redis, 'using') IS NOT NULL) THEN
		using_val := json_extract_path_text(redis, 'using');
	END IF;
	IF (json_extract_path_text(redis, 'type') IS NOT NULL) THEN
		type_val := json_extract_path_text(redis, 'type');
	END IF;
	IF (pk_val IS NULL AND type_val = 'list') THEN
		pk_val := 'list';
	END IF;
	IF(pk_val IS NULL AND (actions != 'empty' OR actions != 'rebuild')) THEN
		RETURN json_build_object('type', 'Error', 'message', '新增、更新或删除具体的Redis缓存时pk参数不能为空!', 'code', 230);
	END IF;
	redis_key := schemas_val || '_' || storage_val || '_' || store_val || ':' || pk_val;
	foreign_table := schemas_val || '_redis_' || storage_val || '_' || store_val;
	SELECT COUNT(*) INTO foreign_key_num FROM base_redis_foreigns WHERE "schemas" = schemas_val AND "storage" = storage_val AND "store" = store_val;
	IF (foreign_key_num > 0) THEN
		SELECT COUNT(*) INTO foreign_table_num FROM information_schema.tables WHERE table_type = 'FOREIGN TABLE' AND table_name = foreign_table;
		IF(actions != 'empty' AND actions != 'rebuild' AND foreign_table_num > 0) THEN
			executesql := 'SELECT COUNT(*) FROM ' || quote_ident(foreign_table) || ' WHERE "key" = $1;';
			EXECUTE executesql INTO redis_key_num USING redis_key;
		ELSE
			foreign_table_num := 0;
		END IF;
	ELSE
		foreign_table_num := 0;
		redis_key_num := 0;
	END IF;
	IF (type_val = 'info') THEN
		key_val := schemas_val || '_' || storage_val || '_' || store_val || ':';
	ELSE
		key_val := redis_key;
	END IF;
	CASE actions
		WHEN 'rebuild' THEN
		PERFORM structure_redis(json_build_object('action', 'empty', 'schemas', 'all'));
		FOR redisRecord IN SELECT * FROM base_redis_foreigns LOOP
			CASE redisRecord.type
				WHEN 'info' THEN
				executesql := 'SELECT array_agg('||redisRecord."primary"||'::VARCHAR) FROM ' || redisRecord."table" || ';';
				EXECUTE executesql INTO foreign_table_array;
				FOREACH pk IN ARRAY foreign_table_array LOOP
					PERFORM structure_redis(
						        json_build_object(
							        'pk', pk,
							        'schemas', redisRecord.schemas,
							        'storage', redisRecord.storage,
							        'store', redisRecord.store,
							        'type', redisRecord."type",
							        'dbindex', redisRecord.dbindex,
							        'method', redisRecord."method",
							        'using', redisRecord."using",
							        'restful', redisRecord."restful",
							        'route', redisRecord.route,
							        'table', redisRecord."table",
							        'primary', redisRecord."primary"
								        )
							        );
				END LOOP;
				WHEN 'list' THEN
				PERFORM structure_redis(
					        json_build_object(
						        'key', redisRecord.key,
						        'type', redisRecord."type",
						        'dbindex', redisRecord.dbindex,
						        'method', redisRecord."method",
						        'using', redisRecord."using",
						        'restful', redisRecord."restful",
						        'route', redisRecord.route,
						        'table', redisRecord."table",
						        'where', redisRecord."where"
							        )
						        );
			ELSE
				PERFORM structure_redis(
					        json_build_object(
						        'key', redisRecord.key,
						        'type', redisRecord."type",
						        'dbindex', redisRecord.dbindex,
						        'method', redisRecord."method",
						        'using', redisRecord."using",
						        'restful', redisRecord."restful",
						        'route', redisRecord.route,
						        'data', redisRecord."data"
							        )
						        );
			END CASE;
		END LOOP;
		RETURN json_build_object('type', 'Success', 'message', '服务器中所有的Redis缓存已经被重新创建!', 'code', 200);
		WHEN 'empty' THEN
		-- Redis数据库清空操作
		CASE
			WHEN (schemas_val = 'all') THEN
			SELECT array_agg(table_name::VARCHAR) INTO foreign_table_array FROM information_schema.tables
			WHERE table_type = 'FOREIGN TABLE' AND table_name LIKE '%redis_%';
			WHEN (storage_val IS NULL AND store_val IS NULL) THEN
			executesql := 'SELECT array_agg(table_name::VARCHAR) FROM information_schema.tables ' ||
			              'WHERE table_type = ''FOREIGN TABLE'' AND table_name LIKE $1';
			EXECUTE executesql INTO foreign_table_array USING schemas_val || '_redis_%';
			WHEN (storage_val IS NOT NULL AND store_val IS NULL) THEN
			executesql := 'SELECT array_agg(table_name::VARCHAR) FROM information_schema.tables ' ||
			              'WHERE table_type = ''FOREIGN TABLE'' AND table_name LIKE $1';
			EXECUTE executesql INTO foreign_table_array USING schemas_val || '_redis_' || storage_val || '_%';
		ELSE
			executesql := 'SELECT array_agg(table_name::VARCHAR) FROM information_schema.tables ' ||
			              'WHERE table_type = ''FOREIGN TABLE'' AND table_name LIKE $1';
			EXECUTE executesql INTO foreign_table_array USING schemas_val || '_redis_' || storage_val || '_' || store_val;
		END CASE;
		IF(foreign_table_array IS NOT NULL) THEN
			FOREACH foreign_table IN ARRAY foreign_table_array LOOP
				SELECT "key", "foreigns", "schemas" INTO item FROM base_redis_foreigns WHERE "foreigns" = foreign_table;
				executesql := 'DELETE FROM ' || quote_ident(item.schemas || '_redis_indexedDB_foreigns') || ' WHERE key = $1;';
				EXECUTE executesql USING item.key;
				IF (foreign_table <> item.schemas || '_redis_indexedDB_foreigns') THEN
					executesql := 'DELETE FROM ' || quote_ident(foreign_table) || ';';
					EXECUTE executesql;
					executesql := 'DROP FOREIGN TABLE IF EXISTS ' || quote_ident(foreign_table)|| ';';
					EXECUTE executesql;
				END IF;
			END LOOP;
			FOR item IN SELECT DISTINCT "schemas" FROM base_redis_foreigns LOOP
				executesql := 'DROP FOREIGN TABLE IF EXISTS ' || quote_ident(item.schemas || '_redis_indexedDB_foreigns') || ';';
				EXECUTE executesql;
			END LOOP;
		END IF;
		RETURN json_build_object('type', 'Success', 'message', '服务器中所有的Redis缓存已经被清空!', 'code', 200);
		WHEN 'remove' THEN
		IF (redis_key_num > 0) THEN
			executesql := 'DELETE FROM ' || quote_ident(foreign_table) || ' WHERE key=$1;';
			EXECUTE executesql USING key_val;
			executesql := 'SELECT COUNT(*) FROM ' || quote_ident(foreign_table) || ';';
			EXECUTE executesql INTO foreign_num;
			IF (foreign_num = 0) THEN
				executesql := 'DROP FOREIGN TABLE IF EXISTS ' || quote_ident(foreign_table) || ';';
				EXECUTE executesql;
			END IF;
		ELSE
			RETURN json_build_object('type', 'Error', 'message', '删除缓存操作时未发现[' || redis_key || ']的Redis缓存!', 'code', 230);
		END IF;
	ELSE
		-- 添加或更新Redis数据缓存
		IF (json_extract_path_text(redis, 'table') IS NOT NULL) THEN
			table_val := json_extract_path_text(redis, 'table');
		END IF;
		IF (json_extract_path_text(redis, 'primary') IS NOT NULL) THEN
			primary_val := json_extract_path_text(redis, 'primary');
			where_val := primary_val || ' = ' || pk_val;
		ELSE
			IF (json_extract_path_text(redis, 'where') IS NOT NULL) THEN
				where_val := json_extract_path_text(redis, 'where');
				IF(type_val = 'info' AND primary_val IS NULL) THEN
					SELECT rec[1] INTO primary_val FROM string_to_array(where_val, '=') AS rec;
				END IF;
			END IF;
		END IF;
		IF (json_extract_path_text(redis, 'data') IS NOT NULL) THEN
			data_val := json_extract_path_text(redis, 'data');
		END IF;
		IF (json_extract_path_text(redis, 'dbindex') IS NOT NULL) THEN
			dbindex := json_extract_path_text(redis, 'dbindex');
		END IF;
		IF (json_extract_path_text(redis, 'route') IS NOT NULL) THEN
			route_val := json_extract_path_text(redis, 'route');
		END IF;
		IF (json_extract_path_text(redis, 'method') IS NOT NULL) THEN
			method_val := json_extract_path_text(redis, 'method');
		END IF;
		IF (json_extract_path_text(redis, 'using') IS NOT NULL) THEN
			using_val := json_extract_path_text(redis, 'using');
		END IF;
		IF(foreign_table_num = 0) THEN
			IF (json_extract_path_text(redis, 'restful') IS NOT NULL) THEN
				restful_val := json_extract_path_text(redis, 'restful');
			ELSE
				RETURN json_build_object('type', 'Error', 'message', '新增Redis缓存时restful参数不能为空!', 'code', 230);
			END IF;
			executesql := 'CREATE FOREIGN TABLE ' ||  quote_ident(foreign_table) || ' ("key" text, "val" json) SERVER redis_server OPTIONS ( database ''' || dbindex || ''');';
			EXECUTE executesql;
		ELSE
			IF (json_extract_path_text(redis, 'dbindex') IS NULL) THEN
				filed_array := array_append(filed_array, 'dbindex');
			END IF;
			IF (json_extract_path_text(redis, 'method') IS NULL) THEN
				filed_array := array_append(filed_array, '"method"');
			END IF;
			IF (json_extract_path_text(redis, 'restful') IS NULL) THEN
				filed_array := array_append(filed_array, '"restful"');
			END IF;
			IF (json_extract_path_text(redis, 'route') IS NULL) THEN
				filed_array := array_append(filed_array, 'route');
			END IF;
			IF (json_extract_path_text(redis, 'using') IS NULL) THEN
				filed_array := array_append(filed_array, '"using"');
			END IF;
			IF(array_length(filed_array, 1) > 0) THEN
				executesql := 'SELECT ' || array_to_string(filed_array, ',') || ' FROM base_redis_foreigns WHERE key = $1 LIMIT 1';
				EXECUTE executesql INTO redisRecord USING key_val;
				IF (json_extract_path_text(redis, 'dbindex') IS NULL) THEN
					dbindex := redisRecord.dbindex;
				ELSE
					dbindex := json_extract_path_text(redis, 'dbindex');
				END IF;
				IF (json_extract_path_text(redis, 'method') IS NULL) THEN
					method_val := redisRecord."method";
				ELSE
					method_val := json_extract_path_text(redis, 'method');
				END IF;
				IF (json_extract_path_text(redis, 'restful') IS NULL) THEN
					restful_val := redisRecord."restful";
				ELSE
					restful_val := json_extract_path_text(redis, 'restful');
				END IF;
				IF (json_extract_path_text(redis, 'route') IS NULL) THEN
					route_val := redisRecord.route;
				ELSE
					route_val := json_extract_path_text(redis, 'route');
				END IF;
				IF (json_extract_path_text(redis, 'using') IS NULL) THEN
					using_val := redisRecord."using";
				ELSE
					using_val := json_extract_path_text(redis, 'using');
				END IF;
			END IF;
		END IF;
		IF (data_val IS NULL) THEN
			CASE
				WHEN (table_val IS NULL) THEN
				RETURN json_build_object('type', 'Error', 'message', '新增或更新Redis缓存时table参数和data参数不能同时为空!', 'code', 230);
				WHEN (table_val IS NOT NULL AND where_val IS NULL) THEN
				IF(type_val = 'info') THEN
					executesql := 'SELECT json_agg(' || table_val || ')->0 FROM "' || table_val || '" LIMIT 1;';
				ELSE
					executesql := 'SELECT json_agg(' || table_val || ') FROM "' || table_val || '";';
				END IF;
				EXECUTE executesql INTO data_val;
				WHEN (table_val IS NOT NULL AND where_val IS NOT NULL) THEN
				IF(type_val = 'info') THEN
					executesql := 'SELECT json_agg(' || table_val || ')->0 FROM "' || table_val || '" WHERE ' || where_val || ' LIMIT 1;';
				ELSE
					executesql := 'SELECT json_agg(' || table_val || ') FROM "' || table_val || '" WHERE ' || where_val || ';';
				END IF;
				EXECUTE executesql INTO data_val;
			ELSE
				IF(type_val = 'list') THEN
					data_val := json_build_array();
				ELSE
					data_val := json_build_object();
				END IF;
			END CASE;
		ELSE
			type_val = 'custom';
			custom_val := data_val;
		END IF;
		cache_val := json_build_object(
				'pk', pk_val,
				'using', using_val,
				'md5', encode(digest(data_val::VARCHAR, 'md5'), 'hex'),
				'sha1', encode(digest(data_val::VARCHAR, 'sha1'), 'hex'),
				'dateline', EXTRACT(epoch FROM current_timestamp(0)::timestamp without time zone),
				'value', data_val
		);
		IF(type_val = 'list') THEN
			primary_val := NULL;
		ELSE
			where_val := NULL;
		end if;
		executesql := 'INSERT INTO base_redis_foreigns ("key", "foreigns", "schemas", "storage", "store", "table", "where", "primary", "data", "type", "dbindex", "method", "using", "restful", "route") VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15) ON CONFLICT ("key") DO UPDATE SET "datetime"=now(), "foreigns"=$2, "schemas"=$3, "storage"=$4, "store"=$5, "table"=$6, "where"=$7, "primary"=$8, "data"=$9, "type"=$10, "dbindex"=$11, "method"=$12, "using"=$13, "restful"=$14, "route"=$15';
		EXECUTE executesql USING key_val, foreign_table, schemas_val, storage_val, store_val, table_val, where_val, primary_val, custom_val, type_val, dbindex, method_val, using_val, restful_val, route_val;
	END CASE;
	IF(key_val != schemas_val || '_indexedDB_foreigns:list') THEN
		PERFORM structure_redis(
			        json_build_object(
				        'key', schemas_val || '_indexedDB_foreigns:list',
				        'dbindex', 15,
				        'restful', 'api/base/getForeigns',
				        'table', 'base_redis_foreigns',
				        'where', 'schemas = ''' || schemas_val || ''''
					        )
				        );
	END IF;
	IF(actions = 'remove') THEN
		RETURN json_build_object('type', 'Success', 'message', '删除Redis缓存[' || redis_key || ']成功!', 'code', 200);
	ELSE
		IF (redis_key_num > 0) THEN
			executesql := 'UPDATE ' ||  quote_ident(foreign_table) || ' SET "val" = $1 WHERE "key" = $2;';
			EXECUTE executesql USING cache_val, redis_key;
			RETURN json_build_object('type', 'Success', 'message', '更新Redis缓存[' || redis_key || ']成功!', 'code', 200);
		ELSE
			executesql := 'INSERT INTO ' ||  quote_ident(foreign_table) || ' ("key", "val") VALUES ($1, $2);';
			EXECUTE executesql USING redis_key, cache_val;
			RETURN json_build_object('type', 'Success', 'message', '添加Redis缓存[' || redis_key || ']成功!', 'code', 200);
		END IF;
	END IF;
	EXCEPTION WHEN OTHERS THEN
	RETURN json_build_object('type', 'Error', 'message', '系统Redis缓存操作失败!', 'error', replace(SQLERRM, '"', '`'), 'sqlstate', SQLSTATE);
END;
$$ LANGUAGE plpgsql;