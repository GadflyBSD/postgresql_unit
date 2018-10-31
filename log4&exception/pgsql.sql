CREATE TABLE base_log4php (
	id SERIAL8,
	timestamp TIMESTAMP(3) WITHOUT TIME ZONE,
	logger VARCHAR(256),
	level VARCHAR(32),
	message TEXT,
	thread INTEGER,
	file VARCHAR(255),
	line VARCHAR(10),
	PRIMARY KEY (id)
);
COMMENT ON TABLE base_log4php IS 'PHP开发日志记录';
COMMENT ON COLUMN base_log4php.id IS '自增主键';
COMMENT ON COLUMN base_log4php.timestamp IS '数据变动时间';
COMMENT ON COLUMN base_log4php.logger IS '日志记录者';
COMMENT ON COLUMN base_log4php.level IS '日志级别';
COMMENT ON COLUMN base_log4php.message IS '日志消息';
COMMENT ON COLUMN base_log4php.thread IS '日志路线';
COMMENT ON COLUMN base_log4php.file IS '日志生成文件';
COMMENT ON COLUMN base_log4php.line IS '日志生成行数';

CREATE TABLE base_exception(
	id          SERIAL8,
	type        VARCHAR(20)     NOT NULL,
	code        INTEGER         NOT NULL,
	title       VARCHAR(50)     NOT NULL,
	message     TEXT            NOT NULL,
	file        VARCHAR(200)    NULL,
	line        INTEGER         NULL,
	trace       JSON            NULL,
	header      JSON            NOT NULL,
	host        VARCHAR(200)    NOT NULL,
	url         VARCHAR(200)    NOT NULL,
	method      VARCHAR(20)     NOT NULL,
	ip          VARCHAR(64)     NOT NULL,
	request     JSON            NULL,
	module      VARCHAR(100)    NULL,
	controller  VARCHAR(100)    NULL,
	action      VARCHAR(100)    NULL,
	model       VARCHAR(100)    NULL,
	dateline    TIMESTAMP(3) WITHOUT TIME ZONE NOT NULL DEFAULT now(),
	PRIMARY KEY (id)
);
COMMENT ON TABLE base_exception IS '异常捕获';
COMMENT ON COLUMN base_exception.id IS '自增主键';
COMMENT ON COLUMN base_exception.type IS '异常类型';
COMMENT ON COLUMN base_exception.code IS '异常状态编码';
COMMENT ON COLUMN base_exception.title IS '异常标题';
COMMENT ON COLUMN base_exception.message IS '异常说明';
COMMENT ON COLUMN base_exception.file IS '异常出现的文件';
COMMENT ON COLUMN base_exception.line IS '异常文件出现的行数';
COMMENT ON COLUMN base_exception.trace IS '异常请求Trace';
COMMENT ON COLUMN base_exception.header IS '异常请求headers';
COMMENT ON COLUMN base_exception.host IS '异常请求主机';
COMMENT ON COLUMN base_exception.url IS '异常请求URL';
COMMENT ON COLUMN base_exception.method IS '异常请求类型';
COMMENT ON COLUMN base_exception.ip IS '异常请求IP';
COMMENT ON COLUMN base_exception.request IS '异常请求数据';
COMMENT ON COLUMN base_exception.module IS '异常请求模块';
COMMENT ON COLUMN base_exception.controller IS '异常请求控制器';
COMMENT ON COLUMN base_exception.action IS '异常请求方法';
COMMENT ON COLUMN base_exception.model IS '异常请求模型';
COMMENT ON COLUMN base_exception.dateline IS '异常请求时间';

CREATE OR REPLACE FUNCTION logic_exception(
	IN exceptions JSON
)RETURNS JSON
AS $$
DECLARE
	type_val VARCHAR(20);
	code_val INTEGER;
	title_val VARCHAR(50);
	message_val TEXT;
	file_val VARCHAR(200) DEFAULT NULL;
	line_val INTEGER DEFAULT NULL;
	trace_val JSON DEFAULT NULL;
	header_val JSON;
	host_val VARCHAR(200);
	url_val VARCHAR(200);
	method_val VARCHAR(20);
	ip_val VARCHAR(64);
	request_val JSON DEFAULT NULL;
	module_val VARCHAR(100) DEFAULT NULL;
	controller_val VARCHAR(100) DEFAULT NULL;
	action_val VARCHAR(100) DEFAULT NULL;
	model_val VARCHAR(100) DEFAULT NULL;
BEGIN
	IF (json_extract_path_text(exceptions, 'type') IS NOT NULL) THEN
		type_val := json_extract_path_text(exceptions, 'type');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常类型不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'code') IS NOT NULL) THEN
		code_val := json_extract_path_text(exceptions, 'code');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常状态编码不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'title') IS NOT NULL) THEN
		title_val := json_extract_path_text(exceptions, 'title');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常标题不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'message') IS NOT NULL) THEN
		message_val := json_extract_path_text(exceptions, 'message');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常说明不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'file') IS NOT NULL) THEN
		file_val := json_extract_path_text(exceptions, 'file');
	END IF;
	IF (json_extract_path_text(exceptions, 'line') IS NOT NULL) THEN
		line_val := json_extract_path_text(exceptions, 'line');
	END IF;
	IF (json_extract_path_text(exceptions, 'trace') IS NOT NULL) THEN
		trace_val := json_extract_path_text(exceptions, 'trace');
	END IF;
	IF (json_extract_path_text(exceptions, 'header') IS NOT NULL) THEN
		header_val := json_extract_path_text(exceptions, 'header');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常请求headers不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'host') IS NOT NULL) THEN
		host_val := json_extract_path_text(exceptions, 'host');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常请求主机不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'url') IS NOT NULL) THEN
		url_val := json_extract_path_text(exceptions, 'url');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常请求URL不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'method') IS NOT NULL) THEN
		method_val := json_extract_path_text(exceptions, 'method');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常请求类型不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'ip') IS NOT NULL) THEN
		ip_val := json_extract_path_text(exceptions, 'ip');
	ELSE
		RETURN json_build_object('type', 'Error', 'message', '异常请求IP不能为空!', 'code', 230);
	END IF;
	IF (json_extract_path_text(exceptions, 'request') IS NOT NULL) THEN
		request_val := json_extract_path_text(exceptions, 'request');
	END IF;
	IF (json_extract_path_text(exceptions, 'module') IS NOT NULL) THEN
		module_val := json_extract_path_text(exceptions, 'module');
	END IF;
	IF (json_extract_path_text(exceptions, 'controller') IS NOT NULL) THEN
		controller_val := json_extract_path_text(exceptions, 'controller');
	END IF;
	IF (json_extract_path_text(exceptions, 'action') IS NOT NULL) THEN
		action_val := json_extract_path_text(exceptions, 'action');
	END IF;
	IF (json_extract_path_text(exceptions, 'model') IS NOT NULL) THEN
		model_val := json_extract_path_text(exceptions, 'model');
	END IF;
	INSERT INTO base_exception("type", "code", "title", "message", "file", "line", "trace", "header", "host",
																					"url", "method", "ip", "request", "module", "controller", "action", "model")
	VALUES (type_val, code_val, title_val, message_val, file_val, line_val, trace_val, header_val, host_val,
					url_val, method_val, ip_val, request_val, module_val, controller_val, action_val, model_val);
	RETURN json_build_object(
			'type', 'Success',
			'msg', '异常捕获: ' || title_val || '操作成功!'
	);
	EXCEPTION WHEN OTHERS THEN
	RETURN json_build_object('type', 'Error', 'msg', '异常捕获操作失败!', 'error', replace(SQLERRM, '"', '`'), 'sqlstate', SQLSTATE);
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION logic_exception(JSON) IS '异常捕获操作';