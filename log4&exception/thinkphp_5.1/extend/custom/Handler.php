<?php
	/**
	 * Created by IntelliJ IDEA.
	 * User: gadflybsd
	 * Date: 2018/10/22
	 * Time: 2:33 PM
	 */
	namespace custom;
	
	use Exception;
	use think\Db;
	use think\facade\Request;
	use think\exception\Handle;
	use think\exception\HttpException;
	use think\exception\ValidateException;
	use think\exception\ProgramException;
	use think\exception\ClassException;
	
	class Handler extends Handle{
		public function render(Exception $e){
			$return = [
				'message'   => $e->getMessage(),
				'code'      => $e->getCode(),
			];
			$exception = [];
			if ($e instanceof ValidateException) {
				$return['code'] = 422;
				$return['message'] = $e->getError();
				$exception['title'] = '数据验证异常';
				$exception['type'] = 'ValidateException';
			}elseif ($e instanceof RouteNotFoundException) {
				$exception['title'] = '路由未发现异常';
				$exception['type'] = 'RouteNotFoundException';
				$return['code'] = $e->getStatusCode();
			}elseif ($e instanceof HttpException) {
				$exception['title'] = 'Http异常';
				$exception['type'] = 'HttpException';
				$return['code'] = $e->getStatusCode();
			}elseif ($e instanceof HttpResponseException) {
				$exception['title'] = 'Http请求异常';
				$exception['type'] = 'HttpResponseException';
				$return['code'] = $e->getStatusCode();
			}elseif ($e instanceof ProgramException) {
				$exception['title'] = '程序异常';
				$exception['type'] = 'ProgramException';
				$return['code'] = $e->getStatusCode();
			}elseif ($e instanceof ClassNotFoundException) {
				$exception['title'] = '对象未发现异常';
				$exception['type'] = 'ClassNotFoundException';
				$return['code'] = $e->getStatusCode();
			}elseif ($e instanceof ErrorException) {
				$exception['title'] = 'ThinkPHP错误异常';
				$exception['type'] = 'ErrorException';
			}elseif ($e instanceof DbException) {
				$exception['title'] = 'Database相关异常';
				$exception['type'] = 'DbException';
			}elseif ($e instanceof PDOException) {
				$exception['title'] = 'PDO异常';
				$exception['type'] = 'PDOException';
				$return['code'] = $e->getStatusCode();
			}elseif ($e instanceof appException) {
				$exception['title'] = 'APP异常';
				$exception['type'] = 'appException';
			}elseif ($e instanceof Exception) {
				$exception['title'] = '常规异常';
				$exception['type'] = 'Exception';
			}else{
				$exception['title'] = '其他异常';
				$exception['type'] = 'OtherException';
			}
			$return['header'] = Request::header();
			$return['request'] = [
				'url'       => Request::url(),
				'method'    => Request::method(),
				'ip'        => Request::ip(),
				'host'      => Request::host(),
				'param'     => Request::param(),
				'module'    => Request::module(),
				'controller'=> Request::controller(),
				'action'    => Request::action(),
				'time'      => Request::time(),
			];
			$return['exception'] = [
				'file'      => $e->getFile(),
				'line'      => $e->getLine(),
			];
			if(config('app_trace')){
				$return['trace'] = $e->getTrace();
			}
			$sql = $this->exception_to_sql(array_merge($exception, $return));
			if($sql['type'] == 'Success')
				return json(array_merge($exception, $return));
			else
				return $sql;
		}
		
		private function exception_to_sql($data){
			Logs::console()->error($data);
			if(config('exception_to_sql')){
				//echo "SELECT logic_exception('".json_encode_plus($data)."');";
				$logic = Db::query("SELECT logic_exception('".json_encode_plus($data)."');");
				return json_decode($logic[0]['logic_exception'], true);
			}else{
				return ['type' => 'Success'];
			}
		}
	}