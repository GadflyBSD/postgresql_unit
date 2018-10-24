# 抽奖实现，带奖项总数、奖项概率和出奖时间分布控制 

### 一、功能说明
* 自定义奖项、出奖概率和出奖数量
* 末等奖（鼓励奖）不需要设定出奖概率和出奖数量
* 任何一个奖项出奖后都将重新统计新的出奖概率
* 分时段控制奖项的出奖概率和出奖数量
* 一个用户只能抽奖一次，不能多次抽奖

### 二、操作方法
1. 将`pgsql.sql`导入`PostgreSQL`数据库中
2. 奖项设置
    * `label`：奖项名称，必填
    * `percent`：中奖概率，最大100.00，当为末等奖时不必填写
    * `totle`：该奖项出奖总数，当为末等奖时不必填写
    ```sql
    INSERT INTO base_lottery (label, percent, totle) VALUES ('一等奖', 8.52, 2),('二等奖', 19.86, 5),('三等奖', 27.34, 10);
    INSERT INTO base_lottery (label) VALUES ('鼓励奖');
    ```
3. 设置奖项出奖时间分布数据
    * `lid`：奖项ID，必须填写
    * `datetime`：开后抽奖后到这个时间为一个时段，必须填写
    * `percent`：本时段该奖项的出奖概率，当设置了`multiple`，出奖概率将无效
    * `multiple`：本时段该奖项的出奖概率将是奖项设置默认概率的倍数，
    * `totle`：本时段该奖项的出奖数量
    > * 当某个时段抽奖参与人数较少时，可能奖项不会完全出来，剩余的未出奖项将计入到下一时段。举例说明：某个时段2等奖设置要出现2个，概率是10，但只出现了一个，下一个时段二等奖设置要出现3个，概率是9，这时候在下一时段系统将自动调整，出奖数为4，概率为12（`9 ÷ 3 x 4 `）
    > * 当某个时段某个奖项出奖后，当前奖项的出奖概率将重新计算，每次出奖后的奖项出奖概率都将重新统计。
    ```sql
    INSERT INTO base_lottery_distribute (lid, datetime, multiple, totle) VALUES
    (1, '2018-10-23 16:30:00', 1.4, 1), (1, '2018-10-23 17:00:00', 1.2, 1);
    INSERT INTO base_lottery_distribute (lid, datetime, percent, totle) VALUES
    (2, '2018-10-23 16:30:00', 16.2, 3), (2, '2018-10-23 17:00:00', 18.1, 2);
    INSERT INTO base_lottery_distribute (lid, datetime, percent, totle) VALUES
    (3, '2018-10-23 16:30:00', 20.6, 4), (3, '2018-10-23 17:00:00', 19.5, 6);
    ```
4. 抽奖逻辑 `SELECT logic_lottery(uid)`
    * `uid`：用户uid
    > 一个用户只能抽奖一次
    ```sql
    SELECT logic_lottery(floor(random() * 999999)::INTEGER);
    ```
5. 获奖名单 `SELECT * FROM base_lottery_log_view`