---
title: rocketMQ集群之消息模式及主题订阅机制
date: 2017-06-17 22:13:45
tags:
- rocketMQ
- 集群
categories: 
- rocketMQ
---

记录rocketMQ

<!--more-->

## JMS

Java Message Service 即Java消息服务应用接口（与JDBC类似，都是提供与厂商无关的访问方法，由厂商自己去做支持实现），它是Java平台上面向消息中间件的技术规范

## 消息模式

rocketMQ不遵循任何规范，包括上述的JMS，但参考了各种规范和同类产品的设计思想，形成自身的一套自定义机制，简单说都是通过订阅主题的方式进行发送和接收任务的，但是支持集群和广播两种消息模式

### 集群模式

设置消费端对象属性：MessageModel.CLUSTERING；该模式可以达到类似ActiveMQ水平扩展负载均衡消费消息的实现，特殊的一点是该模式支持生产端先发数据到MQ上，消费端订阅主题在生产端发送数据之后也可以接受到数据，相对灵活

### 广播模式

设置消费端对象属性：MessageModel.BROADCASTING；该模式相当于生产端发送数据到MQ上，每一个订阅该主题的消费端都能均可获得MQ上的数据

## 广播模式模拟

### Producer端

```bash
/**
 * 模拟rocketMQ的消息模式
 * @author lf
 *
 */
public class Producer {
	public static void main(String[] args) throws MQClientException, InterruptedException {
		DefaultMQProducer producer = new DefaultMQProducer("ProducerGroup");
		producer.setNamesrvAddr("192.168.154.30:9876;192.168.154.31:9876");
		producer.start();
		for(int i=0; i<10; i++) {
			try {
				Message message = new Message("MessageModel", 
						"TagModel", 
						"Key"+i, 
						("Hello MessageModel"+i).getBytes());
				SendResult sendResult = producer.send(message);
				System.out.println(sendResult);
			}catch(Exception e) {
				e.printStackTrace();
				Thread.sleep(1000);
			}
		}
		producer.shutdown();
	}
}
```

### Consumer端

```bash
/**
 * 消费端使用广播模式接收数据（c2与c1基本一致，略）
 * @author lf
 *
 */
public class Consumer1 {
	public Consumer1() throws Exception{
		DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("ConsumerGroup");
		consumer.setNamesrvAddr("192.168.154.30:9876;192.168.154.31:9876");
		consumer.subscribe("MessageModel", "*");
		consumer.setMessageModel(MessageModel.BROADCASTING);
		consumer.registerMessageListener(new Listener());
		consumer.start();
		System.out.println("c1 start...");
        //System.out.println("c2 start...");
	}
	
	class Listener implements MessageListenerConcurrently {
		@Override
		public ConsumeConcurrentlyStatus consumeMessage(List<MessageExt> msg, ConsumeConcurrentlyContext context) {
			try {
				for(MessageExt me : msg) {
					String topic = me.getTopic();
					String tag = me.getTags();
					String key = me.getKeys();
					String body = new String(me.getBody(), "UTF-8");
					System.out.println("topic:"+topic + "tag:"+tag + "key:"+key + "body:"+body);
				}
			}catch(Exception e) {
				e.printStackTrace();
				return ConsumeConcurrentlyStatus.RECONSUME_LATER;
			}
			return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
		}
	}
	
	public static void main(String[] args) throws Exception{
		Consumer1 consumer = new Consumer1();
	}
}
```

### 运行测试

先启动consumer1和consumer2监听着，再启动producer发送消息，发现consumer控制台并没有显示接受内容

```bash
producer控制台显示发送成功：
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000004788, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-a, queueId=0], queueOffset=2]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000004824, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-a, queueId=1], queueOffset=2]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F00000000000048C0, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-a, queueId=2], queueOffset=1]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F000000000000495C, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-a, queueId=3], queueOffset=1]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F0000000000000D88, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-b, queueId=0], queueOffset=1]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F0000000000000E24, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-b, queueId=1], queueOffset=1]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F0000000000000EC0, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-b, queueId=2], queueOffset=1]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1F00002A9F0000000000000F5C, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-b, queueId=3], queueOffset=1]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F00000000000049F8, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-a, queueId=0], queueOffset=3]
SendResult [sendStatus=SLAVE_NOT_AVAILABLE, msgId=C0A89A1E00002A9F0000000000004A94, messageQueue=MessageQueue [topic=MessageModel, brokerName=broker-a, queueId=1], queueOffset=3]


c1控制台无内容打印：
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
c1 start...


c2控制台无内容打印：
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
c2 start...
```

使用相同的topic再一次发送消息，发现消费端控制台成功接收到第二次发送的消息

```bash
c1控制台打印：
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
c1 start...
topic:MessageModeltag:TagModelkey:Key0body:Hello MessageModel0
topic:MessageModeltag:TagModelkey:Key2body:Hello MessageModel2
topic:MessageModeltag:TagModelkey:Key3body:Hello MessageModel3
topic:MessageModeltag:TagModelkey:Key1body:Hello MessageModel1
topic:MessageModeltag:TagModelkey:Key4body:Hello MessageModel4
topic:MessageModeltag:TagModelkey:Key5body:Hello MessageModel5
topic:MessageModeltag:TagModelkey:Key8body:Hello MessageModel8
topic:MessageModeltag:TagModelkey:Key6body:Hello MessageModel6
topic:MessageModeltag:TagModelkey:Key7body:Hello MessageModel7
topic:MessageModeltag:TagModelkey:Key9body:Hello MessageModel9


c2控制台打印：
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
c2 start...
topic:MessageModeltag:TagModelkey:Key2body:Hello MessageModel2
topic:MessageModeltag:TagModelkey:Key3body:Hello MessageModel3
topic:MessageModeltag:TagModelkey:Key0body:Hello MessageModel0
topic:MessageModeltag:TagModelkey:Key1body:Hello MessageModel1
topic:MessageModeltag:TagModelkey:Key4body:Hello MessageModel4
topic:MessageModeltag:TagModelkey:Key5body:Hello MessageModel5
topic:MessageModeltag:TagModelkey:Key6body:Hello MessageModel6
topic:MessageModeltag:TagModelkey:Key7body:Hello MessageModel7
topic:MessageModeltag:TagModelkey:Key8body:Hello MessageModel8
topic:MessageModeltag:TagModelkey:Key9body:Hello MessageModel9
```

## 订阅主题机制

当消费端consumer1和consumer2启动后在启动producer使用广播模式发送消息到MQ，发现producer端打印发送成功，但是在消费端没有被马上的接收?

原因分析：
```bash
消费端先启动时在broker上还没有监听的topic；
而是在生产端发送消息带有数据的topic时（并且在配置文件如broker-a.properties中配置了AutoCreateTopicEnable=true以及自动创建订阅组=true）才会去创建topic；
因此当broker上创建topic完成，consumer端自身的检测机制已经暂时不去取对应topic中的消息，类似延迟功能，但是消息一定会被接收消费，只不过会等待一段时间
```

解决方案：
```bash
如果想要实现消息发送后立即被消费端接收，通过运维使用mqadmin指令先创建topic或者在rocketMQ可视化控制台添加创建topic，然后在producer和consumer中都使用该topic
（代码中尝试在consumer端先创建topic报异常，只能通过管理员创建，估计是避免受到外界干扰破坏创建大量的topic）
测试成功：在控制台先创建topic信息，然后使用该新创建的topic启动consumer和producer，结果消息立马被consumer接收了
```

类似kafka就是必须先创建topic队列，再启动consumer和producer；而activeMQ和rabbitMQ则是consumer监听队列，当生产者发送消息就立马接收消费

## 控制台查看

查看可视化控制台发现之前第一次发送的在消费端没有显示被接受的消息，同样也被接受消费了

![png1](/img/20170617_1.png)