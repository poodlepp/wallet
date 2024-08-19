[TOC]
### 神鱼发零花钱
> 合约支持小鱼不断提取零花钱
- 24h不能超过100$
- 单笔不超过50$
- 30天不能超过 1ETH

### 功能设计
#### 基本检查
- 单笔提取金额不能为0，不能超过50$

#### 核心数据结构
- 使用链表结构，形式：mapping(uint256 => uint256) public moneyInOneDayMap;
  - 第一笔提取 key:time1   value: （amount1-高128bit，  time2-低128bit）
  - 第二笔提取 key:time2   value: （amount2-高128bit，  time3-低128bit）
  - 以此类推
  - 最后一笔   key:timen   value: （amount_n-高128bit，  paidMoney）
    - 最后一笔的paidMoney比较特殊，放在此处可以节约一个slot
- 使用一个动态数据结构维护了提取记录&顺序
  - amount,time  都明显小于2^128

#### 提取函数处理流程（类似于滑动窗口）
- 检查当前链表中记录，已经超出24h的直接去除
- 24H内已经支付金额 + 本次提取金额，判断不能超过100$
- 最新一笔订单放在链表末尾，同时更新startKey,endKey
- 按照CEI规则，transfer放在末尾

### 时间&空间复杂度&gas分析
- 时间复杂度
  - 每次提取只需要处理头尾的数据，复杂度O(1)
- 空间复杂度
  - 每笔订单会占用一个slot，对旧订单进行了delete
  - 空间占用主要取决于操作频率
    - 假设一天仅操作一次，那么平均slot占用为1
    - 假设一天操作1w次，那么平均slot占用为1w
  - 可以理解为复杂度 O(N)
- 单次gas对比
  - 普通transfer方法 - testNormalTransfer 
    - 消耗 29811gas
    - > forge test --match-test testNormalTransfer -vvvvv
  - 钱包提取 - testWithdraw_success_next_day
    - 提取频率：1天2次
    - 消耗：28195gas （稳定之后的gas消耗）
    - > forge test --match-test testWithdraw_success_next_day -vvvvv
  - 钱包提取 - testWithdraw_success_frequently
    - 提取频率：1天8次
    - 消耗：28195gas （稳定之后的gas消耗）
    - > forge test --match-test testWithdraw_success_frequently -vvvvv

### 细节优化
- 自定义error节省gas
- block.timestamp 多次使用，先存入memory中，减少gas消耗
- startKey,endKey 多次调用，提前放入memory,避免多次查询storage，减少gas消耗
- 废弃slot，直接delete，获得gas补贴
- amount + time指针，放入一个slot，大量节约gas
- 链表结构既能存储大量记录，又能记录顺序，适合两端修改的场景
- 还可以考虑使用yul,unchecked等进一步优化

### 30天不超过1 ETH，实现思考
- 链上实现
  - 还可以继续使用链表结构，但是会占用更多的slot
  - 需要接入chainlink预言机，进行ETH-USDT兑换
- 链下链上结合
  - 每个节点存储截至now的提取累计值，不再使用滑动窗口
  - 超过一天的数据可以考虑merkle来组织，链上仅记录merkle root
    - 可以考虑一天一棵树
    - 甚至可以将多个用户的一起组织为merkle tree，只要能提供验证功能即可
  - 用户提取时，链下先进行计算，找到支撑证据节点
    - 将提供证据的头尾节点提交，通过merkle tree验证，也可保证安全性

### 项目运行指南
- make install   (相关依赖版本已经配置好)
- make test