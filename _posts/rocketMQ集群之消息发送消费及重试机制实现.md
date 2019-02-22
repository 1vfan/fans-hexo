---
title: rocketMQ集群之消息发送消费及重试机制实现
date: 2017-06-17 22:13:45
tags:
- rocketMQ
- 集群
categories: 
- rocketMQ
---

记录rocketMQ在双主模式实现简单的消息发送、消费以及重试机制 

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

## 实现步骤

```bash
生产者：
	创建DefaultMQProducer类设定生产者名称，设置相关配置和setNamesrvAddr，调用start方法启动；
	使用Message类实例化消息，参数为主题、标签、键、内容；
	使用send方法发送消息，最后关闭生产者

消费者：
	创建DefaultMQPushConsumer类设定消费者名称，设置相关配置和setNamesrvAddr；
	设置DefaultMQPushConsumer实例的订阅主题，使用subscribe("主题名称", "标签1 || 标签2 ..")方法订阅；
	（一个消费者对象可以订阅多个主题；也可以使用 || 对多标签内容进行合并获取，也可以使用 * 代表获取所有标签内容）
	消费者实例进行注册监听：使用registerMessageListener方法；
	监听类实现MessageListenerConcurrently接口，重写consumeMessage方法接收数据；
	（ConsumeConcurrentlyStatus.RECONSUME_LATER：表示失败等待轮询重新消费、ConsumeConcurrentlyStatus.CONSUME_SUCCESS：表示消费成功）
	消费者实例对象调用start方法
```

## 生产端

```bash
/**
 * 生产消息
 * @author lf
 *
 */
public class Producer {

	public static void main(String[] args) throws MQClientException, InterruptedException{
		DefaultMQProducer producer = new DefaultMQProducer("producerA");
		
		/**
		 *  producer配置项：
		 * 
		 *  producerGroup DEFAULT_PRODUCER Producer组名，多个Producer如果属于一个应用，发送同样的消息，则应该将它们归于同一组。
		    createTopicKey HZ798 在发送消息时，自动创建服务器不存在的topic,需要指定key
		    defaultTopicQueueNums 4 在发送消息时，自动创建服务器不存在的topic，默认创建的队列数
		    sendMsgTimeout 10000  发送消息超过时间，单位毫秒
		    compressMsgBodyOverHowmuch 4096 消息Body超过多大开始压缩（Consumer收到消息会自动解压缩），单位字节
		    retryTimesWhenSendFailed 重试次数（可以配置）
		    retryAnotherBrokerWhenNotStoreOK FALSE 如果发送消息返回sendResult,但是sendStatus!=SEND_OK，是否重试发送
		    maxMessageSize 131072 客户端限制的消息大小，超过报错，同时服务器端也会限制（默认128K）
		    transactionCheckListener 事务消息回查监听器，如果发送事务消息必须设置
		    checkThreadPoolMinSize 1 Broker回查Producer事务状态时，线程池大小
		    checkThreadPoolMaxSize 1 Broker回查Producer事务状态时，线程池大小
		    checkRequestHoldMax 2000 Broker回查Producer事务状态时，Producer本地缓冲请求队列大小
		 */
		/**
		    producer.setProducerGroup("groupA");
		    producer.setCreateTopicKey("HZ798");
		    producer.setDefaultTopicQueueNums(4);
		    producer.setSendMsgTimeout(10000);
		    producer.setCompressMsgBodyOverHowmuch(4096);
		    producer.setRetryTimesWhenSendFailed(10);
		    producer.setRetryAnotherBrokerWhenNotStoreOK(false);
		    producer.setMaxMessageSize(131072);
		*/
		
		producer.setRetryTimesWhenSendFailed(10);
		
		producer.setNamesrvAddr("192.168.154.30:9876;192.168.154.31:9876");
		producer.start();
		
		for(int i=0; i<1; i++) {
			Message message = new Message(
					"TopicA",
					"TagA",
					"KeyA",
					("Hello RocketMQ" + i).getBytes());
			try {
				SendResult sendResult = producer.send(message);
				System.out.println(sendResult);
			} catch (Exception e) {
				e.printStackTrace();
				Thread.sleep(1000);
			}
		}
		
		producer.shutdown();
	}
}
```

producer控制台打印

```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000000D50, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=0], queueOffset=8]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000000DDE, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=1], queueOffset=8]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000000E6C, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=2], queueOffset=4]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000000EFA, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=3], queueOffset=4]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F00000000000008E0, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-b, queueId=0], queueOffset=4]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F000000000000096E, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-b, queueId=1], queueOffset=4]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F00000000000009FC, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-b, queueId=2], queueOffset=4]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F0000000000000A8A, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-b, queueId=3], queueOffset=4]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000000F88, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=0], queueOffset=9]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000001016, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=1], queueOffset=9]
```

![png1](/img/rocketmq/20170617_2.png)

## 消费端

```bash
/**
 * 消费消息
 * @author lf
 *
 */
public class Consumer {
	public static void main(String[] args) throws MQClientException, InterruptedException{
		DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("consumerA");

		/**
		 *  push Consumer 配置：
		 *  
		    messageModel 消息模型，支持两种：1.集群消费 CLUSTERING、2.广播消费BRODCASTING
		    consumerFromWhere CONSUME_FROM_LAST_OFFSET Consumer启动后，默认从什么位置开始消费
		    allocateMessageQueueStrategy  AllocateMessageQueueAveragely Rebalance算法实现策略
		    Subscription {} 订阅关系
		    messageListener 消息监听器
		    offsetStore 消费进度储存
		    consumerThreadMin 10  消费线程池数量 
		    consumerThreadMax 20 消费线程池数量
		    consumerConcurrentlyMaxSpan 2000 单队列并行消费的最大跨度
		    pullThresholdForQueue 1000  拉消息本地队列缓存消息最大数
		    pullinterval 拉消息间隔，由于是长轮询，所以是0；但是如果应用了流控，也可以设置成>0的值，单位毫秒
		    consumerMessageBatchMaxSize 1 批量消费，一次消费多少条消息
		    pullBatchSize 32 批量拉消息，一次最多拉多少条
		 */

		consumer.setConsumeThreadMax(20);
		consumer.setConsumeThreadMin(10);
		consumer.setNamesrvAddr("192.168.154.30:9876;192.168.154.31:9876");
		//consumer.setMessageModel(MessageModel.BROADCASTING);
		//consumer.setMessageModel(MessageModel.CLUSTERING);
		
		/**
		 * 设置Consumer第一次启动是从对利润头部开始消费还是队列尾部开始消费
		 * 如果非第一次启动，那么按照上次消费的位置继续消费
		 */
		consumer.setConsumeFromWhere(ConsumeFromWhere.CONSUME_FROM_FIRST_OFFSET);
		//consumer.setConsumeFromWhere(ConsumeFromWhere.CONSUME_FROM_LAST_OFFSET);
		
		//消费者订阅主题
		consumer.subscribe("TopicA", "*");
		
		consumer.registerMessageListener(new MessageListenerConcurrently() {
			@Override
			public ConsumeConcurrentlyStatus consumeMessage(List<MessageExt> msgs, ConsumeConcurrentlyContext context) {
				MessageExt msg = msgs.get(0);
				try {	
					//String msgId = msg.getMsgId();
					String topic = msg.getTopic();
					String tag = msg.getTags();
					String body = new String(msg.getBody(), "UTF-8");
					String orignMsgId = msg.getProperties().get(MessageConst.PROPERTY_ORIGIN_MESSAGE_ID);
					System.out.println("-->收到消息： orignMsgID: " + orignMsgId + ", topic："+topic + ", tag:" + tag + ", body: " + body);
					//int a = 1/0;
				} catch (Exception e) {
					//e.printStackTrace();
					System.out.println("-->重试次数："+msg.getReconsumeTimes());
					if(msg.getReconsumeTimes() == 3) {
						System.out.println("----------达到最大重试次数，记录日志----------");
						return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
					}
					//requeue
					return ConsumeConcurrentlyStatus.RECONSUME_LATER;
				}
				return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
			}
		});
		
		consumer.start();
		System.out.println("consumer start");
	}
}
```

consumer控制台打印

```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
consumer start
-->收到消息： msgID: C0A89A1F00002A9F00000000000008E0, topic：TopicA, tag:TagA, body: Hello RocketMQ4
-->收到消息： msgID: C0A89A1F00002A9F00000000000009FC, topic：TopicA, tag:TagA, body: Hello RocketMQ6
-->收到消息： msgID: C0A89A1F00002A9F0000000000000A8A, topic：TopicA, tag:TagA, body: Hello RocketMQ7
-->收到消息： msgID: C0A89A1F00002A9F000000000000096E, topic：TopicA, tag:TagA, body: Hello RocketMQ5
-->收到消息： msgID: C0A89A1E00002A9F0000000000000EFA, topic：TopicA, tag:TagA, body: Hello RocketMQ3
-->收到消息： msgID: C0A89A1E00002A9F0000000000000E6C, topic：TopicA, tag:TagA, body: Hello RocketMQ2
-->收到消息： msgID: C0A89A1E00002A9F0000000000000D50, topic：TopicA, tag:TagA, body: Hello RocketMQ0
-->收到消息： msgID: C0A89A1E00002A9F0000000000000F88, topic：TopicA, tag:TagA, body: Hello RocketMQ8
-->收到消息： msgID: C0A89A1E00002A9F0000000000001016, topic：TopicA, tag:TagA, body: Hello RocketMQ9
-->收到消息： msgID: C0A89A1E00002A9F0000000000000DDE, topic：TopicA, tag:TagA, body: Hello RocketMQ1
```

![png2](/img/rocketmq/20170617_3.png)

## 重试机制

生产端投递一条数据

```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000001E7A, messageQueue=MessageQueue [topic=TopicA, brokerName=broker-a, queueId=0], queueOffset=12]
```

消费端添加一个异常int a = 1/0，使该条消息进入重试状态，当达到设置的最大重试次数退出

```bash
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
consumer start
-->收到消息： orignMsgID: null, topic：TopicA, tag:TagA, body: Hello RocketMQ0
java.lang.ArithmeticException: / by zero
-->重试次数：0
-->收到消息： orignMsgID: C0A89A1E00002A9F0000000000001E7A, topic：TopicA, tag:TagA, body: Hello RocketMQ0
java.lang.ArithmeticException: / by zero
-->重试次数：1
-->收到消息： orignMsgID: C0A89A1E00002A9F0000000000001E7A, topic：TopicA, tag:TagA, body: Hello RocketMQ0
java.lang.ArithmeticException: / by zero
-->重试次数：2
-->收到消息： orignMsgID: C0A89A1E00002A9F0000000000001E7A, topic：TopicA, tag:TagA, body: Hello RocketMQ0
java.lang.ArithmeticException: / by zero
-->重试次数：3
----------达到最大重试次数，记录日志----------
```

![png3](/img/rocketmq/20170617_4.png)