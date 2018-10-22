# `ThinkPHP 5.1`下`log4php`和异常数据库存储

### 一、简要说明

### 二、安装 `Composer`
```shell
# 下载composer.phar 
$ wget https://dl.laravel-china.org/composer.phar -O /usr/local/bin/composer

# 把composer.phar移动到环境下让其变成可执行 
$ chmod a+x /usr/local/bin/composer
$ composer config -g repo.packagist composer https://packagist.phpcomposer.com

# 测试
$ composer -V 
```

### 三、 使用 `Composer` 安装 `ThinkPHP 5.1`和相关类库
```shell
$ composer create-project topthink/think thinkphp5.1 --prefer-dist
$ cd thinkphp5.1
$ composer require topthink/think-helper
$ composer require topthink/think-image
$ composer require topthink/think-captcha
$ composer require adodb/adodb-php
$ composer require apache/log4php
$ composer require ccampbell/chromephp
```