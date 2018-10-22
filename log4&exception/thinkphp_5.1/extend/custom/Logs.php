<?php
	/**
	 * Created by IntelliJ IDEA.
	 * User: gadflybsd
	 * Date: 2018/10/22
	 * Time: 2:33 PM
	 */
	namespace custom;
	
	class Logs{
		public static function log4php($param = 'log4php'){
			\Logger::configure(config('log4php.'));
			return \Logger::getLogger($param);
		}
		
		public static function console(){
			//include_once('vendor/ccampbell/chromephp/ChromePhp.php');
			return \ChromePhp::getInstance();
		}
	}