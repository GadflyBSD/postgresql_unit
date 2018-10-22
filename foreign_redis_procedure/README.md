# PostgreSQL 通过外部表操作redis的存储过程

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