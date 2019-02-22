---
title: rocketMQ集群之消息严格顺序消费实现
date: 2017-06-18 10:34:02
tags:
- rocketMQ
- 集群
categories: 
- rocketMQ
---

记录rocketMQ在双主模式下实现严格顺序的消息消费

<!--more-->

## jar包依赖

```bash
netty-all-4.0.25.Final.jar
rocketmq-client-3.2.6.jar
rocketmq-common-3.2.6.jar
rocketmq-remoting-3.2.6.jar
fastjson-1.2.3.jar
slf4j-api-1.7.5.jar
```

## 生产端

Producer控制台打印
```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
---->ID:1
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003A26, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=1], queueOffset=0]Body:2017-08-03 11:27:12Hello rocketMQ 0
---->ID:1
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003ACC, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=1], queueOffset=1]Body:2017-08-03 11:27:12Hello rocketMQ 1
---->ID:1
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003B72, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=1], queueOffset=2]Body:2017-08-03 11:27:12Hello rocketMQ 2
---->ID:1
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003C18, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=1], queueOffset=3]Body:2017-08-03 11:27:12Hello rocketMQ 3
---->ID:1
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003CBE, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=1], queueOffset=4]Body:2017-08-03 11:27:12Hello rocketMQ 4
---->ID:2
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003D64, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=2], queueOffset=0]Body:2017-08-03 11:27:12Hello rocketMQ 0
---->ID:2
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003E0A, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=2], queueOffset=1]Body:2017-08-03 11:27:12Hello rocketMQ 1
---->ID:2
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003EB0, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=2], queueOffset=2]Body:2017-08-03 11:27:12Hello rocketMQ 2
---->ID:2
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003F56, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=2], queueOffset=3]Body:2017-08-03 11:27:12Hello rocketMQ 3
---->ID:2
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000003FFC, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=2], queueOffset=4]Body:2017-08-03 11:27:12Hello rocketMQ 4
---->ID:3
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F00000000000040A2, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=3], queueOffset=0]Body:2017-08-03 11:27:12Hello rocketMQ 0
---->ID:3
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000004148, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=3], queueOffset=1]Body:2017-08-03 11:27:12Hello rocketMQ 1
---->ID:3
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F00000000000041EE, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=3], queueOffset=2]Body:2017-08-03 11:27:12Hello rocketMQ 2
---->ID:3
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000004294, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=3], queueOffset=3]Body:2017-08-03 11:27:12Hello rocketMQ 3
---->ID:3
---->SendResult:SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F000000000000433A, messageQueue=MessageQueue [topic=TopicOrder, brokerName=broker-a, queueId=3], queueOffset=4]Body:2017-08-03 11:27:12Hello rocketMQ 4
```



## 消费端


Consumer2控制台打印
```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
Consumer2 start...
---->msg:MessageExt [queueId=1, storeSize=166, queueOffset=0, sysFlag=0, bornTimestamp=1501730832295, bornHost=/192.168.154.1:54766, storeTimestamp=1501730830133, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003A26, commitLogOffset=14886, bodyCRC=1267369230, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key0, WAIT=true, TAGS=TagA}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 0
---->msg:MessageExt [queueId=1, storeSize=166, queueOffset=1, sysFlag=0, bornTimestamp=1501730832584, bornHost=/192.168.154.1:54766, storeTimestamp=1501730830287, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003ACC, commitLogOffset=15052, bodyCRC=1015920024, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key1, WAIT=true, TAGS=TagA}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 1
---->msg:MessageExt [queueId=1, storeSize=166, queueOffset=2, sysFlag=0, bornTimestamp=1501730832600, bornHost=/192.168.154.1:54766, storeTimestamp=1501730830301, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003B72, commitLogOffset=15218, bodyCRC=629466146, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key2, WAIT=true, TAGS=TagA}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 2
---->msg:MessageExt [queueId=1, storeSize=166, queueOffset=3, sysFlag=0, bornTimestamp=1501730832629, bornHost=/192.168.154.1:54766, storeTimestamp=1501730830332, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003C18, commitLogOffset=15384, bodyCRC=1384371380, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key3, WAIT=true, TAGS=TagA}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 3
---->msg:MessageExt [queueId=1, storeSize=166, queueOffset=4, sysFlag=0, bornTimestamp=1501730832648, bornHost=/192.168.154.1:54766, storeTimestamp=1501730830352, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003CBE, commitLogOffset=15550, bodyCRC=1290223895, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key4, WAIT=true, TAGS=TagA}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 4
```

Consumer1控制台打印
```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
Consumer1 start...
---->msg:MessageExt [queueId=2, storeSize=166, queueOffset=0, sysFlag=0, bornTimestamp=1501730834674, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832402, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003D64, commitLogOffset=15716, bodyCRC=1267369230, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key0, WAIT=true, TAGS=TagB}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 0
---->msg:MessageExt [queueId=3, storeSize=166, queueOffset=0, sysFlag=0, bornTimestamp=1501730834882, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832582, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F00000000000040A2, commitLogOffset=16546, bodyCRC=1267369230, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key0, WAIT=true, TAGS=TagC}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 0
---->msg:MessageExt [queueId=3, storeSize=166, queueOffset=1, sysFlag=0, bornTimestamp=1501730834920, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832609, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000004148, commitLogOffset=16712, bodyCRC=1015920024, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key1, WAIT=true, TAGS=TagC}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 1
---->msg:MessageExt [queueId=2, storeSize=166, queueOffset=1, sysFlag=0, bornTimestamp=1501730834732, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832452, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003E0A, commitLogOffset=15882, bodyCRC=1015920024, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key1, WAIT=true, TAGS=TagB}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 1
---->msg:MessageExt [queueId=2, storeSize=166, queueOffset=2, sysFlag=0, bornTimestamp=1501730834772, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832476, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003EB0, commitLogOffset=16048, bodyCRC=629466146, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key2, WAIT=true, TAGS=TagB}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 2
---->msg:MessageExt [queueId=3, storeSize=166, queueOffset=2, sysFlag=0, bornTimestamp=1501730834943, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832645, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F00000000000041EE, commitLogOffset=16878, bodyCRC=629466146, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key2, WAIT=true, TAGS=TagC}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 2
---->msg:MessageExt [queueId=3, storeSize=166, queueOffset=3, sysFlag=0, bornTimestamp=1501730834974, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832700, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000004294, commitLogOffset=17044, bodyCRC=1384371380, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key3, WAIT=true, TAGS=TagC}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 3
---->msg:MessageExt [queueId=2, storeSize=166, queueOffset=3, sysFlag=0, bornTimestamp=1501730834789, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832491, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003F56, commitLogOffset=16214, bodyCRC=1384371380, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key3, WAIT=true, TAGS=TagB}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 3
---->msg:MessageExt [queueId=2, storeSize=166, queueOffset=4, sysFlag=0, bornTimestamp=1501730834828, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832532, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F0000000000003FFC, commitLogOffset=16380, bodyCRC=1290223895, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key4, WAIT=true, TAGS=TagB}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 4
---->msg:MessageExt [queueId=3, storeSize=166, queueOffset=4, sysFlag=0, bornTimestamp=1501730835035, bornHost=/192.168.154.1:54766, storeTimestamp=1501730832797, storeHost=/192.168.154.30:10911, msgId=C0A89A1E00002A9F000000000000433A, commitLogOffset=17210, bodyCRC=1290223895, reconsumeTimes=0, preparedTransactionOffset=0, toString()=Message [topic=TopicOrder, flag=0, properties={MIN_OFFSET=0, MAX_OFFSET=5, KEYS=Key4, WAIT=true, TAGS=TagC}, body=35]], body:2017-08-03 11:27:12Hello rocketMQ 4
```