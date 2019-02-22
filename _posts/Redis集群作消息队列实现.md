---
title: Redis集群作消息队列实现
date: 2017-06-13 20:04:21
tags:
- Redis
- 集群
- Java
- SpringBoot
categories: 
- Redis
---
记录使用Redis集群+SpringBoot实现消息队列的功能，项目中使用的主从数据库以及分表就不做赘述

<!--more-->

# 前期准备

添加redis依赖jar包
```bash
<dependency>  
    <groupId>org.springframework.boot</groupId>  
    <artifactId>spring-boot-starter-redis</artifactId>  
    <version>1.4.3.RELEASE</version>  
</dependency> 
```

application.yml文件中添加redis集群配置

```bash
spring: 
  http: 
    encoding:
      charset: UTF-8       
  redis:   
    pool: 
      min-idle: 100
      max-idle: 100
      max-wait: -1
      max-active: 1000
    timeout: 6000  
    cluster: 
      ## 最大的重定向次数：如果选择的主节点没连上可以重定向到另外的主节点上
      max-redirects: 1000
      nodes: 
        - 192.168.154.22:7001  
        - 192.168.154.22:7002  
        - 192.168.154.22:7003  
        - 192.168.154.22:7004  
        - 192.168.154.22:7005  
        - 192.168.154.22:7006 
```

消息发送优先级分类

```bash
public enum RedisPriorityQueue {
	
	//7,8,9 紧急
	FAST_QUEUE("fast"),
	
	//4,5,6 正常 
	NORMAL_QUEUE("normal"),
	
	//1,2,3 可延迟
	DEFER_QUEUE("defer");
	
	private String code;

	private RedisPriorityQueue(String code) {
		this.code = code;
	}

	public String getCode() {
		return code;
	}
}
```

消息发送状态分类

```bash
public enum MessageStatus {

	/** 暂存/待发送 */
	DRAFT("0"),
	
	/** 发送中/已经进入Redis队列 */
	SEND_IN("1"),
	
	/** 发送成功 */
	NEED_OK("2"),
	
	/** 发送失败 */
	NEED_ERR("3");

	private String code;

	private MessageStatus(String code) {
		this.code = code;
	}

	public String getCode() {
		return code;
	}
}
```

消息对象实体类

```bash
public class MessageSend {
    //主键
    private String sendId;
    //消息内容
    private String sendContent;
    //消息优先级
    private Long sendPriority;
    //重复发送次数
    private Long sendCount; 
    //消息状态
    private String sendStatus;
    //版本号（乐观更新）
    private Long version;
    //更新时间（数据库自动更新）
    private Date updateTime;

    //getter setter
}
```

# 整体架构
![png1](/img/20170613_1.png)

## 生产端

接收请求，负责将消息对象投递到redis队列中

```bash
@RestController
public class ProducerController {

	private static Logger logger = LoggerFactory.getLogger(ProducerController.class);
	
	@Autowired
	private MessageSendService messageSendService;
	
        @RequestMapping(value="/send", produces= {"application/json;charset=UTF-8"})
	public void send(@RequestBody(required=false) MessageSend messageSend) throws Exception {
	    try {
	    	messageSend.setSendId(KeyUtil.generatorUUID());
	    	messageSend.setSendCount(0L);
	    	messageSend.setVersion(0L);
	    	messageSend.setSendStatus(MessageStatus.DRAFT.getCode());
                //数据落地存入数据库
	    	messageSendService.insertMessage(messageSend);
	    	//数据投递到redis队列，并修改数据库状态
	    	messageSendService.sendRedis(messageSend);
	    }catch(Exception e) {
	    	//1.记录日志
                logger.error("异常信息: {}", e);
                //2.业务异常处理
                //3.手工回滚异常
                throw new RuntimeException(e);
	    }
	}
}
```

按优先级投递消息到redis中

```bash
@Service
public class MessageSendService {

	private static Logger logger = LoggerFactory.getLogger(MessageSendService.class);
	
	@Autowired
	private MessageSendMapper messageSendMapper;
	
	@Autowired
	private RedisTemplate<String, String> redisTemplate;
	
	public void sendRedis(MessageSend messageSend) {
                //查询一次获取数据库自动生成的updatetime
		messageSend = messageSendMapper.selectByPrimaryKey(messageSend.getSendId());
		Long ret = 0L;
		Long size = 0L;
		Long priority = messageSend.getSendPriority();
		ListOperations<String, String> opsForList = redisTemplate.opsForList();
        	//存入redis中的是消息对象转成Json的一条字符串
		if(priority < 4L) {
        	//如果投递时用rightPush，就用leftPop拉取；如果用leftPush，就用rightPop拉取
			ret = opsForList.rightPush(RedisPriorityQueue.DEFER_QUEUE.getCode(), FastJsonConvertUtil.convertObjectToJSON(messageSend));
			size = opsForList.size(RedisPriorityQueue.DEFER_QUEUE.getCode());
		}else if(priority > 3L && priority < 7L) {
			ret = opsForList.rightPush(RedisPriorityQueue.NORMAL_QUEUE.getCode(), FastJsonConvertUtil.convertObjectToJSON(messageSend));
			size = opsForList.size(RedisPriorityQueue.NORMAL_QUEUE.getCode());
		}else {
			ret = opsForList.rightPush(RedisPriorityQueue.FAST_QUEUE.getCode(), FastJsonConvertUtil.convertObjectToJSON(messageSend));
			size = opsForList.size(RedisPriorityQueue.FAST_QUEUE.getCode());
		}
		//无论是否成功，只要进行消息投递就count++
		messageSend.setSendCount(messageSend.getSendCount() + 1);
		if(ret == size) {
			//说明reids投递成功	
			messageSend.setSendStatus(MessageStatus.SEND_IN.getCode());
			messageSendMapper.updateByPrimaryKeySelective(messageSend);
		}else {
			//投递失败的时候 
			messageSend1Mapper.updateByPrimaryKeySelective(messageSend);
			logger.info("-----消息进入队列失败, 等待轮询机制重新投递, id : {}-----", messageSend.getSendId());
		}
	}
```

## 消费端

定时的去redis队列中拉取消息并移除redis队列数据，根据优先级可以设定多个定时任务

```bash
//定时任务的配置类
//默认会有特定的线程池等配置，实现SchedulingConfigurer接口可以自定义定时配置
@Configuration
@EnableScheduling
public class TaskSchedulerConfig implements SchedulingConfigurer {

	@Override
	public void configureTasks(ScheduledTaskRegistrar taskRegistrar) {
		taskRegistrar.setScheduler(taskScheduler());
	}
	
	@Bean(destroyMethod="shutdown")
	public Executor taskScheduler(){
		return Executors.newScheduledThreadPool(100);
	}
}
```

根据优先级设置定时任务从redis队列中拉取数据

```bash
@Component
public class ConsumerMessageTask {
	
	private static final Logger logger = LoggerFactory.getLogger(ConsumerMessageTask.class);

	@Autowired
	private RedisTemplate<String, String> redisTemplate;
	
	@Autowired
	private MessageSendService messageSendService;
	
	@Scheduled(initialDelay=5000, fixedDelay=2000)
	public void intervalFast() {
		getLeftPop(RedisPriorityQueue.FAST_QUEUE.getCode());
	}

    @Scheduled(initialDelay=5000, fixedDelay=5000)
	public void intervalNormal() {
		getLeftPop(RedisPriorityQueue.Normal_QUEUE.getCode());
	}

    @Scheduled(initialDelay=5000, fixedDelay=10000)
	public void intervalDefer() {
		getLeftPop(RedisPriorityQueue.Defer_QUEUE.getCode());	
	}

    private void getLeftPop(String code){
        ListOperations<String, String> opsForList = redisTemplate.opsForList();
        String messageForJson = opsForList.leftPop(code);
		if(!StringUtils.isBlank(messageForJson)) {
			MessageSend messageSend = FastJsonConvertUtil.convertJSONToObject(messageForJson, MessageSend.class);
			messageSendService.sendMessageForOrder(messageSend);
		}	
    }
}
```

```bash
@Service
public class MessageSendService {

	private static Logger logger = LoggerFactory.getLogger(MessageSendService.class);
	
	@Autowired
	private MessageSendMapper messageSendMapper;

	public void sendMessageForOrder(MessageSend messageSend) {
		try {
			//更新数据状态，使用乐观锁（版本号）更新数据库
			messageSend.setSendStatus(MessageStatus.NEED_OK.getCode());
			int ret = messageSendMapper.updateByPrimaryKeyAndVersion(messageSend);
			if(ret == 0) {
				//更新失败，版本号冲突，更改投递状态等待轮询重发
				messageSend.setSendStatus(MessageStatus.DRAFT.getCode());
				messageSendMapper.updateByPrimaryKey(messageSend);
				logger.info("发送邮件失败，版本号有冲突，等待重新发送,  id : {}" , messageSend.getSendId();
			}else if(ret == 1) {
				logger.info("发送邮件成功， id : {}" , messageSend.getSendId();;
			}	
		}catch(Exception e) {
			logger.error("异常信息: {}", e);
			//count  达到5次不再重发
			if(messageSend.getSendCount() > 4) {
				messageSend.setSendStatus(MessageStatus.NEED_ERR.getCode());
				logger.info("发送邮件失败， id : {}" , messageSend.getSendId();
			} else {
				messageSend.setSendStatus(MessageStatus.DRAFT.getCode());
				logger.info("发送邮件失败，等待重新发送， id : {}" , messageSend.getSendId();
			}
			messageSendMapper.updateByPrimaryKeyAndVersion(messageSend);
			throw new RuntimeException(e);
		}
	}	
}
```

## 生产端消息重投

定时的去（最好使用只读的从数据库）读取待发送的消息对象（失败重发的消息），投递到redis队列中

```bash
@Component
public class RetryMessageTask {

	private static final Logger logger = LoggerFactory.getLogger(RetryMessageTask.class);
	
	@Autowired
	private MessageSendService messageSendService;
	
	@Scheduled(initialDelay=5000 ,fixedDelay=10000)
	public void retry() {
		logger.info("==========轮询重新发送消息==========");
        	//读取从数据库中待发送的消息	
		List<MessageSend> list = messageSendService.queryDraftList();
		for(MessageSend messageSend : list) {
            		//重新发送
			messageSendService.sendRedis(messageSend);
		}
	}	
}


@Service
public class MessageSendService {

	private static Logger logger = LoggerFactory.getLogger(MessageSendService.class);
	
	@Autowired
	private MessageSendMapper messageSendMapper;

    //自定义只读数据源注解
    @ReadOnlyConnection
    public List<MessageSend> queryDraftList() {
        List<MessageSend> list = new ArrayList<MessageSend>();
        list.addAll(messageSendMapper.queryDraftList());
        return list;
    }
```











