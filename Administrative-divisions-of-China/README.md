# 中华人民共和国五级行政区划数据库

## 一、数据视图 `VIEW`
* 中华人民共和国五级行政区划视图 `dividion_view`
    * `code` 完整行政区划代码
    * `provinceCode` 省级代码
    * `province` 省级名称
    * `cityCode` 地市级代码
    * `city` 地市级名称
    * `areaCode` 区县级代码
    * `area` 区县级名称
    * `streetCode` 乡镇、街道级代码
    * `street` 乡镇、街道级名称
    * `village` 村级名称
    * `address` 详细地址
    
    
* 中华人民共和国公安局、分局区划视图 `domicile_view`
    * `code` 完整行政区划代码
    * `provinceCode` 省级代码
    * `province` 省级名称
    * `cityCode` 地市级代码
    * `city` 地市级名称
    * `area` 区县级名称
    * `domicile` 户籍所在地

## 二、服务支撑函数 `Function`

* 判断给定参数所代表的年是否为闰年
> * 参数：需要进行判断的年份
> * 返回值：Boolean
```sql
SELECT func_is_leap_year(year);
```

* 判断给定参数所代表的年范围里面有多少个闰年
> * 参数：① 开始时间， ② 结束时间
> * 返回值：INTEGER
```sql
SELECT func_have_leap_year(start_year, end_year);
```

* 身份证号码校验
> * 参数：需要校验的身份证号码
> * 返回值：JSON类型
```sql
SELECT func_verificate_card_number(card_number);
```

* 随机概率函数
> * 参数：
> * 返回值：
```sql
SELECT func_random_percent();
```

## 三、逻辑存储过程
* 按需生成一个虚拟个人信息存储过程
```sql
SELECT logic_build_people(json_build_object(
    'min_age', '最小年龄，默认：18',
    'max_age', '最小年龄，默认：65',
    'age', '指定生成者的年龄，默认：在最小和最大年龄范围间随机生成',
    'year', '指定生成者的出生年份，默认：在最小和最大年龄范围间随机生成',
    'month', '指定生成者的出生月份，默认：在最小和最大年龄范围间随机生成',
    'day', '指定生成者的出生日期，不能单独指定，如果指定必须与月份共同指定，默认：在最小和最大年龄范围间随机生成',
    'dividion', '指定生成者的省市区代码，2位代码指定省份，4位代码指定省市，6位代码指定省市区县，默认：在全国范围内随机生成',
    'height', '指定生成者的身高，默认：随机生成',
    'weight', '指定生成者的体重，默认：随机生成',
    'face', '指定生成者的脸型，默认：随机生成'
    'feature', '指定生成者的身体特征，默认：随机生成'
));
```