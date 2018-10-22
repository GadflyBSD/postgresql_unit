DROP FUNCTION IF EXISTS base_structure_redis(JSON);
DROP TABLE IF EXISTS "public"."base_redis_foreigns";
DROP TYPE IF EXISTS methods;
DROP TYPE IF EXISTS data_type;
DROP TYPE IF EXISTS actions;

CREATE TYPE data_type AS ENUM('list', 'info');
CREATE TYPE methods AS ENUM('get', 'post', 'put', 'delete', 'options');
CREATE TYPE actions AS ENUM('empty', 'remove', 'upsert', 'rebuild');

CREATE TABLE "public"."base_redis_foreigns" (
	"key" VARCHAR(200) NOT NULL,
	"foreigns" VARCHAR(150) NOT NULL,
	"schemas" VARCHAR(100) NOT NULL,
	"storage" VARCHAR(100) NOT NULL,
	"store" VARCHAR(100) NOT NULL,
	"table" VARCHAR(150) NOT NULL,
	"primary" VARCHAR(150) DEFAULT NULL,
	"where" VARCHAR(250) DEFAULT NULL,
	"type" data_type DEFAULT 'list',
	"dbindex" SMALLINT DEFAULT 0,
	"method" methods DEFAULT 'get',
	"using" VARCHAR(100) DEFAULT NULL,
	"restful" VARCHAR(200) DEFAULT NULL,
	"route" JSON DEFAULT NULL,
	"datetime" TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT now(),
	PRIMARY KEY ("key")
);
COMMENT ON TABLE "public"."base_redis_foreigns" IS 'Redis外部表数据';
COMMENT ON COLUMN "public"."base_redis_foreigns"."key" IS 'Redis数据键名';
COMMENT ON COLUMN "public"."base_redis_foreigns"."foreigns" IS 'Redis外部表名';
COMMENT ON COLUMN "public"."base_redis_foreigns"."schemas" IS '前端模式名称';
COMMENT ON COLUMN "public"."base_redis_foreigns"."storage" IS '前端本地存储方式';
COMMENT ON COLUMN "public"."base_redis_foreigns"."store" IS '前端本地存储store名';
COMMENT ON COLUMN "public"."base_redis_foreigns"."table" IS '数据库查询表名';
COMMENT ON COLUMN "public"."base_redis_foreigns"."type" IS '数据缓存类型';
COMMENT ON COLUMN "public"."base_redis_foreigns"."dbindex" IS 'Redis数据库id';
COMMENT ON COLUMN "public"."base_redis_foreigns"."method" IS '数据请求方式';
COMMENT ON COLUMN "public"."base_redis_foreigns"."using" IS '数据用途';
COMMENT ON COLUMN "public"."base_redis_foreigns"."restful" IS '数据请求RestFul路径';
COMMENT ON COLUMN "public"."base_redis_foreigns"."route" IS '数据请求Route方式参数';
COMMENT ON COLUMN "public"."base_redis_foreigns"."datetime" IS '最后更新时间';

/**
 # PostgreSQL redis操作存储过程

## 1. 依耐关系(首先需要安装`Redis_fdw`)
> 关于Redis_fdw 详见：https://pgxn.org/dist/redis_fdw/
```sql
CREATE EXTENSION IF NOT EXISTS redis_fdw;
CREATE SERVER redis_server FOREIGN DATA WRAPPER redis_fdw OPTIONS (address '127.0.0.1', port '6379');
CREATE USER MAPPING FOR PUBLIC SERVER redis_server OPTIONS (password '');
```

## 2. 操作方法、使用范列
> * `structure_redis` 存储过程可以用于某个表的触发器中,或其他数据逻辑操作的存储过程中
> * 当数据层某个表的数据发生变化时运行该存储过程快速创建、更新或删除Redis数据，应用层不需要去操作`Redis`，只需要读取`Redis`即可
> * 会在数据库中生成一个`"public"."police_redis_foreign"`的数据表,用于存放Redis服务器数据库MAP(0~15)，请自行规划好Redis数据存放位置
> * `Redis`服务器数据库15位置处，`KEY` 值为`indexedDBStorage:redisForeign`存放着`"public"."base_redis_foreign"`的数据表的数据，方便应用层查找调用数据
> * `Redis`服务器数据库15位置处，`KEY` 值为`indexedDBStorage:redisMap`存放着`"public"."base_redis_map_view"`的视图的数据，方便应用层查找调用数据
> * `Redis`的`KEY`值生成规则：`storage:pk`
### 2.1 清空`Redis`缓存
```sql
SELECT structure_redis(json_build_object(
	'type', 'empty',
	'foreign', '外部表名称(不指定则清空所有)',
	'redis', 'base_redis(默认)'
);
```

### 2.2. 创建或刷新一条`JSON`对象形式的`Redis`缓存记录，用于单一数据的缓存
*  #### 2.2.1 将指定表`table`的`where`查询结果的第一行记录以JSON对象形式进行Redis数据缓存
```sql
SELECT structure_redis(
	json_build_object(
		'pk', 4,                                    -- 数据主键值
		'type', 'info',															-- 数据类型, 必须指定为`info`
		'databases', 1,															-- 指定Redis的databases，范围：0~15， 默认：0
		'storage', 'sessionStorage',                -- 前端存储位置, 用于构造Redis的Key，默认indexedDBStorage
		'store', 'userInfo',                        -- 前端存储store, 用于构造Redis的Key
		'table', 'police_view_user',                -- 数据查询表名
		'where', 'uid=4'                            -- 数据查询条件
	)
);
```
* #### 2.2.2 将指定表`table`的主键`primary`等于`pk`的查询结果的第一行记录以JSON对象形式进行Redis数据缓存
```sql
SELECT structure_redis(
	json_build_object(
		'pk', 4,                                    -- 数据主键值
		'type', 'info',															-- 数据类型, 必须指定为`info`
		'databases', 1,															-- 指定Redis的databases，范围：0~15， 默认：0
		'storage', 'sessionStorage',                -- 前端存储位置, 用于构造Redis的Key，默认indexedDBStorage
		'store', 'userInfo',                        -- 前端存储store, 用于构造Redis的Key
		'table', 'police_view_user',                -- 数据查询表名
		'primary', 'uid'                            -- 查询主键列名
	)
);
```
### 2.3 将指定表`table`的`where`查询结果以JSON数组对象形式创建或刷新一条Redis缓存记录，用于数据列表的缓存
```sql
SELECT structure_redis(
	json_build_object(
		'pk', 'policerList',                            -- 数据PK值(此处并非主键值，用以标注唯一性)
		'type', 'list',																	-- 数据类型，可以不必指定，如果指定必须指定为`list`
		'databases', 1,																	-- 指定Redis的databases，范围：0~15， 默认：0
		'storage', 'indexedDB',                  -- 前端存储位置, 用于构造Redis的Key，默认indexedDBStorage
		'store', 'userList',                            -- 前端存储store, 用于构造Redis的Key
		'table', 'police_view_user_list',               -- 数据查询表名
		'where', 'user_group::JSONB @> json_build_array(''police'')::JSONB'    -- 数据查询条件
	)
);
```

### 2.4 将指定数据`data`进行Redis数据缓存
```sql
SELECT base_structure_redis(
				 json_build_object(
					 'schemas', 'ionic',
					 'pk', 'policerList',															-- 数据PK值(此处并非主键值，用以标注唯一性)
					 'type', 'list',																	-- 数据类型，可以不必指定，如果指定必须指定为`list`
					 'dbindex', 1,																		-- 指定Redis的databases，范围：0~15， 默认：0
					 'storage', 'indexedDB',													-- 前端存储位置, 用于构造Redis的Key，默认indexedDB
					 'store', 'user',																	-- 前端存储store, 用于构造Redis的Key
					 'table', 'police_view_user_list',								-- 数据查询表名
					 'where', 'user_group::JSONB @> json_build_array(''police'')::JSONB',		-- 数据查询条件
					 'restful', 'api/base/getUserList'
						 )
					 );
```

### 2.5 删除一条指定`pk`的Redis缓存记录
```sql
SELECT structure_redis(
	json_build_object(
		'pk', 4,
		'schemas', 'ionic',
		'storage', 'indexedDB',
		'store', 'user'
	)
);
```
或者
```sql
SELECT base_structure_redis(json_build_object('action', 'remove', 'key', 'ionic.indexedDB_user:19'));
```

## 3 参数说明

参数|参数说明|可选值|类型|是否必填|默认值
-|-|-|-|-|-
type|数据或操作类型|list、info、remove、empty|ENUM|false|list
schemas|缓存分区，可用于按用户组或项目功能进行数据可见性的分区|NULL|string|false|app
storage|前端本地存储方式|NULL|string|除完全清空Redis外均必填|NULL
store|前端本地存储store名|NULL|string|除完全清空Redis外均必填|NULL
table|缓存所需的数据库表名|NULL|string|缓存数据时未指定data情况下必填|NULL
where|缓存所需的数据库查询方法|NULL|string|false|NULL
data|所需缓存的数据|NULL|JSON|缓存数据时未指定table情况下必填|NULL
dbindex|Redis数据库ID，该缓存数据在Redis中的位置|NULL|number|false|0
pk|当缓存列表数据时为list；当缓存info数据时为数据主键|NULL|string or number|缓存数据类型为info时必填|list
method|数据请求方法|get、post、put、delete、options|ENUM|false|get
restful|RestFul请求路径|NULL|string|新增缓存数据时必填|NULL
route|数据Route请求方式所需的参数|NULL|JSON|false|NULL

 */
CREATE OR REPLACE FUNCTION base_structure_redis(
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
	type_val data_type DEFAULT 'list';
	method_val methods DEFAULT 'get';
	restful_val VARCHAR(200);
	route_val JSON DEFAULT NULL;
	data_val JSON DEFAULT NULL;
	redis_key VARCHAR(100);
	using_val VARCHAR(50) DEFAULT 'base';
	cache_val JSON;
	actions actions DEFAULT 'upsert';
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
		 json_extract_path_text(redis, 'pk') IS NOT NULL
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
		PERFORM base_structure_redis(json_build_object('action', 'empty', 'schemas', 'all'));
		FOR redisRecord IN SELECT * FROM base_redis_foreigns LOOP
			IF(redisRecord.type = 'info') THEN
				executesql := 'SELECT array_agg('||redisRecord."primary"||'::VARCHAR) FROM ' || redisRecord."table" || ';';
				EXECUTE executesql INTO foreign_table_array;
				FOREACH pk IN ARRAY foreign_table_array LOOP
					PERFORM base_structure_redis(json_build_object(
																				 'pk', pk,
																				 'schemas', redisRecord.schemas,
																				 'storage', redisRecord.storage,
																				 'store', redisRecord.store,
																				 'type', redisRecord.type,
																				 'dbindex', redisRecord.dbindex,
																				 'method', redisRecord.method,
																				 'using', redisRecord."using",
																				 'restful', redisRecord.restful,
																				 'route', redisRecord.route,
																				 'table', redisRecord."table",
																				 'primary', redisRecord."primary"));
				END LOOP;
			ELSE
				PERFORM base_structure_redis(json_build_object(
																			 'key', redisRecord.key,
																			 'type', redisRecord.type,
																			 'dbindex', redisRecord.dbindex,
																			 'method', redisRecord.method,
																			 'using', redisRecord."using",
																			 'restful', redisRecord.restful,
																			 'route', redisRecord.route,
																			 'table', redisRecord."table",
																			 'where', redisRecord.where));
			END IF;
		END LOOP;
		RETURN json_build_object('type', 'Success', 'message', '服务器中所有的Redis缓存已经被重新创建!', 'code', 200);
		WHEN 'empty' THEN
		-- Redis数据库清空操作
		CASE
			WHEN (schemas_val = 'all') THEN
			SELECT array_agg(table_name::VARCHAR) INTO foreign_table_array FROM information_schema.tables
			WHERE table_type = 'FOREIGN TABLE' AND table_name LIKE '%redis_%';
			WHEN (storage_val IS NULL AND store_val IS NULL) THEN
			executesql := 'SELECT array_agg(table_name::VARCHAR) FROM information_schema.tables' ||
										'WHERE table_type = ''FOREIGN TABLE'' AND table_name LIKE $1';
			EXECUTE executesql INTO foreign_table_array USING schemas_val || '_redis_%';
			WHEN (storage_val IS NOT NULL AND store_val IS NULL) THEN
			executesql := 'SELECT array_agg(table_name::VARCHAR) FROM information_schema.tables' ||
										'WHERE table_type = ''FOREIGN TABLE'' AND table_name LIKE $1';
			EXECUTE executesql INTO foreign_table_array USING schemas_val || '_redis_' || storage_val || '_%';
		ELSE
			executesql := 'SELECT array_agg(table_name::VARCHAR) FROM information_schema.tables' ||
										'WHERE table_type = ''FOREIGN TABLE'' AND table_name LIKE $1';
			EXECUTE executesql INTO foreign_table_array USING schemas_val || '_redis_' || storage_val || '_' || store_val;
		END CASE;
		IF(foreign_table_array IS NOT NULL) THEN
			FOR item IN SELECT "key", "foreigns", "schemas" FROM base_redis_foreigns LOOP
				FOREACH foreign_table IN ARRAY foreign_table_array LOOP
					IF (item.foreigns = foreign_table) THEN
						executesql := 'DELETE FROM ' || quote_ident(item.schemas || '_redis_indexedDB_foreigns') || ' WHERE key = $1;';
						EXECUTE executesql USING item.key;
						executesql := 'DELETE FROM ' || quote_ident(foreign_table) || ';';
						EXECUTE executesql;
						executesql := 'DROP FOREIGN TABLE IF EXISTS ' || quote_ident(foreign_table)|| ';';
						EXECUTE executesql;
					END IF;
				END LOOP;
			END LOOP;
			FOR item IN SELECT DISTINCT "schemas" FROM base_redis_foreigns LOOP
				executesql := 'DROP FOREIGN TABLE IF EXISTS ' || quote_ident(item.schemas || ' _redis_indexedDB_foreigns') || ';';
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
				IF(type_val = 'info') THEN
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
				filed_array := array_append(filed_array, 'method');
			END IF;
			IF (json_extract_path_text(redis, 'restful') IS NULL) THEN
				filed_array := array_append(filed_array, 'restful');
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
				END IF;
				IF (json_extract_path_text(redis, 'method') IS NULL) THEN
					method_val := redisRecord.method;
				END IF;
				IF (json_extract_path_text(redis, 'restful') IS NULL) THEN
					restful_val := redisRecord.restful;
				END IF;
				IF (json_extract_path_text(redis, 'route') IS NULL) THEN
					route_val := redisRecord.route;
				END IF;
				IF (json_extract_path_text(redis, 'using') IS NULL) THEN
					using_val := redisRecord."using";
				END IF;
			END IF;
		END IF;
		CASE
			WHEN (table_val IS NULL AND data_val IS NULL) THEN
			RETURN json_build_object('type', 'Error', 'message', '新增或更新Redis缓存时table参数和data参数不能同时为空!', 'code', 230);
			WHEN (table_val IS NOT NULL AND where_val IS NULL) THEN
			IF(type_val = 'info') THEN
				executesql := 'SELECT json_agg(' || table_val || ')->0 FROM "' || table_val || '" LIMIT 1;';
			ELSE
				executesql := 'SELECT json_agg(' || table_val || ') FROM "' || table_val || '";';
			END IF;
			WHEN (table_val IS NOT NULL AND where_val IS NOT NULL) THEN
			IF(type_val = 'info') THEN
				executesql := 'SELECT json_agg(' || table_val || ')->0 FROM "' || table_val || '" WHERE ' || where_val || ' LIMIT 1;';
			ELSE
				executesql := 'SELECT json_agg(' || table_val || ') FROM "' || table_val || '" WHERE ' || where_val || ';';
			END IF;
		END CASE;
		EXECUTE executesql INTO data_val;
		IF(data_val IS NULL) THEN
			IF(type_val = 'list') THEN
				data_val := json_build_array();
			ELSE
				data_val := json_build_object();
			END IF;
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
		executesql := 'INSERT INTO public.base_redis_foreigns ("key", "foreigns", "schemas", "storage", "store", "table", "where", "primary", "type", "dbindex", "method", "using", "restful", "route") VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) ON CONFLICT ("key") DO UPDATE SET "datetime"=now(), "foreigns"=$2, "schemas"=$3, "storage"=$4, "store"=$5, "table"=$6, "where"=$7, "primary"=$8, "type"=$9, "dbindex"=$10, "method"=$11, "using"=$12, "restful"=$13, "route"=$14';
		EXECUTE executesql USING key_val, foreign_table, schemas_val, storage_val, store_val, table_val, where_val, primary_val, type_val, dbindex, method_val, using_val, restful_val, route_val;
	END CASE;
	IF(key_val != schemas_val || '_indexedDB_foreigns:list') THEN
		PERFORM base_structure_redis(json_build_object(
																	 'key', schemas_val || '_indexedDB_foreigns:list',
																	 'dbindex', 15,
																	 'restful', 'api/base/getForeigns',
																	 'table', 'base_redis_foreigns',
																	 'where', 'schemas = ''' || schemas_val || ''''));
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