<?php
	/**
	 * Created by IntelliJ IDEA.
	 * User: gadflybsd
	 * Date: 2018/10/22
	 * Time: 2:27 PM
	 */
	$db = config('database.');
	return [
		'rootLogger' => array(
			'appenders' => array('default'),
		),
		'appenders' => array(
			'default' => array(
				'class' => 'LoggerAppenderPDO',
				'params' => array(
					'dsn'       => $db['type'].':host='.$db['hostname'].';port='.$db['hostport'].';dbname='.$db['database'],
					'user'      => $db['username'],
					'password'  => $db['password'],
					'table'     => 'police_log4php'
				)
			)
		)
	];