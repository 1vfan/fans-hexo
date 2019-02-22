---
title: 异步处理RESTful服务实现方案
date: 2017-03-13 19:43:01
tags:
- Spring
- SpringBoot
- RESTful
- Async
categories: 
- SSM
---

记录Spring中异步处理RESTful服务实现方案

<!--more-->

## Runnable异步处理

如图，传统的同步处理请求过程：当Http请求时服务器会起一个线程来处理业务逻辑最后返回Http响应，整个过程中该线程都处在工作状态，由于服务器所管理的线程数是一定的，当所有线程都在工作一旦请求数量超出就无法处理了.

所谓异步处理就是当Http请求时服务器的主线程接收请求，然后开启一个副线程处理业务逻辑并返回处理结果，最后主线程返回Http响应，在副线程工作的过程中主线程处于空闲状态可以去接收别的Http请求，那么服务器的吞吐量就会有明显的提升了.

![png1](/img/SSM/Async/Async.png)

使用Runnable异步处理方式实现上图所示的异步

```java
@RestController
public class AsyncController {

    Logger logger = LoggerFactory.getLogger(AsyncController.class);
	
    @RequestMapping("/async/callable")
    public Callable<String> order() {
        logger.info("主线程开始");
        Callable<String> result = new Callable<String>() {
            @Override
            public String call() throws Exception {
                logger.info("副线程开始");
                Thread.sleep(1000);
                logger.info("副线程结束");
                return "success";
            }
        };
        logger.info("主线程结束");
        return result;
    }
}
```

返回结果显示主线程[nio-9080-exec-1]在接收Http请求后启用了副线程立刻就返回了，主线程并没有等待副线程[MvcAsync1]处理完成，而是空闲下来去接收别的Http请求，所以异步的优点就使得服务器处理Http请求的吞吐量得到提升.

```java
2017-03-13 16:15:13.201  INFO 19816 --- [nio-9080-exec-1] com.stefan.web.async.AsyncController     : 主线程开始
2017-03-13 16:15:13.202  INFO 19816 --- [nio-9080-exec-1] com.stefan.web.async.AsyncController     : 主线程结束
2017-03-13 16:15:13.208  INFO 19816 --- [      MvcAsync1] com.stefan.web.async.AsyncController     : 副线程开始
2017-03-13 16:15:14.208  INFO 19816 --- [      MvcAsync1] com.stefan.web.async.AsyncController     : 副线程结束
```

## DeferredResult异步处理

但实际开发场景要复杂很多，以下图订单为例：接收订单的应用1和处理订单的应用2是在不同的服务器上，同时应用1中接收Http请求的线程1和监听处理结果并返回Http响应的线程2是完全隔离的，这样的场景就无法使用Runable方式实现，这时候就需要DeferredResult将线程1和线程2关联起来

![png2](/img/SSM/Async/DeferredResult.png)

模拟消息队列当placeOrder有值代表有下单的消息，当completeOrder有值代表有订单完成的消息

```java
@Component
public class MockQueue {

    Logger logger = LoggerFactory.getLogger(MockQueue.class);
	
    private String placeOrder;
	
    private String completeOrder;

    public String getPlaceOrder() {
        return placeOrder;
    }

    public void setPlaceOrder(String placeOrder) {
        new Thread(() -> {
            logger.info("新线程模拟应用2监听并接收下单消息");
            if(StringUtils.isNotBlank(placeOrder)) {
                try {
                    logger.info("模拟业务逻辑处理");
                    Thread.sleep(1000);
                    logger.info("模拟订单完成返回消息");
                    this.completeOrder = placeOrder;
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }

    public String getCompleteOrder() {
        return completeOrder;
    }

    public void setCompleteOrder(String completeOrder) {
        this.completeOrder = completeOrder;
    }	
}
```

利用DeferredResult<String>将接收Http请求的线程1和处理业务逻辑并返回结果的线程2关联进行信息的交互

```java
@Component
public class DeferredResultHolder {

    private Map<String, DeferredResult<String>> map = new HashMap<String, DeferredResult<String>>();

    public Map<String, DeferredResult<String>> getMap() {
        return map;
    }

    public void setMap(Map<String, DeferredResult<String>> map) {
        this.map = map;
    }
}
```

模拟线程2定时拉取订单消息，处理业务逻辑并返回结果

```java
@Component
public class QueueListener implements ApplicationListener<ContextRefreshedEvent>{

    Logger logger = LoggerFactory.getLogger(QueueListener.class);
	
    @Autowired
    public MockQueue mockQueue;
	
    @Autowired
    public DeferredResultHolder deferredResultHolder;
	
    @Override
    public void onApplicationEvent(ContextRefreshedEvent event) {
        new Thread(() -> {
            logger.info("循环判断模拟监听消息队列中是否有完成订单的消息");
            while(true) {
                if(StringUtils.isNotBlank(mockQueue.getCompleteOrder())) {
                    logger.info("模拟拉取消息队列的完成订单消息后清空队列中的该消息");
                    deferredResultHolder.getMap().get(mockQueue.getCompleteOrder()).setResult("complete resolve order!");
                    mockQueue.setCompleteOrder(null);
                }else {
                    logger.info("暂时没有订单完成的消息，监听等待100ms");
                    try {
                        Thread.sleep(100);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }
            }
        }).start();
    }
}
```

接收Http请求的主线程，模拟发送消息到消息队列，并接收处理结果，返回Http响应.

```java
@RestController
public class AsyncController {

    Logger logger = LoggerFactory.getLogger(AsyncController.class);
	
    @Autowired
    public MockQueue mockQueue;
	
    @Autowired
    public DeferredResultHolder deferredResultHolder;
		
    @RequestMapping("/async/order")
    public DeferredResult<String> order() {
        logger.info("主线程开始");
        String orderNumber = RandomStringUtils.random(8);
        mockQueue.setPlaceOrder(orderNumber);
        DeferredResult<String> result = new DeferredResult<String>();
        deferredResultHolder.getMap().put(orderNumber, result);
        logger.info("主线程结束");
        return result;
    }
}
```

Http请求 http://localhost:9080/async/order 查看日志信息

```java
2017-03-13 11:21:06.889  INFO 15636 --- [       Thread-7] com.stefan.web.async.QueueListener       : 循环判断模拟监听消息队列中是否有完成订单的消息
2017-03-13 11:21:06.892  INFO 15636 --- [       Thread-7] com.stefan.web.async.QueueListener       : 暂时没有订单完成的消息，监听等待100ms
2017-03-13 11:21:07.124  INFO 15636 --- [           main] s.b.c.e.t.TomcatEmbeddedServletContainer : Tomcat started on port(s): 9080 (http)
2017-03-13 11:21:07.131  INFO 15636 --- [           main] com.stefan.DemoApplication               : Started DemoApplication in 11.165 seconds (JVM running for 12.517)
2017-03-13 11:21:07.217  INFO 15636 --- [       Thread-7] com.stefan.web.async.QueueListener       : 暂时没有订单完成的消息，监听等待100ms
2017-03-13 11:21:12.447  INFO 15636 --- [nio-9080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring FrameworkServlet 'dispatcherServlet'
2017-03-13 11:21:12.447  INFO 15636 --- [nio-9080-exec-1] o.s.web.servlet.DispatcherServlet        : FrameworkServlet 'dispatcherServlet': initialization started
2017-03-13 11:21:12.472  INFO 15636 --- [nio-9080-exec-1] o.s.web.servlet.DispatcherServlet        : FrameworkServlet 'dispatcherServlet': initialization completed in 25 ms
2017-03-13 11:21:12.511  INFO 15636 --- [nio-9080-exec-1] com.stefan.web.async.AsyncController     : 主线程开始
2017-03-13 11:21:12.514  INFO 15636 --- [nio-9080-exec-1] com.stefan.web.async.AsyncController     : 主线程结束
2017-03-13 11:21:12.514  INFO 15636 --- [      Thread-10] com.stefan.web.async.MockQueue           : 新线程模拟应用2监听并接收下单消息
2017-03-13 11:21:12.516  INFO 15636 --- [      Thread-10] com.stefan.web.async.MockQueue           : 模拟业务逻辑处理
2017-03-13 11:21:12.538  INFO 15636 --- [       Thread-7] com.stefan.web.async.QueueListener       : 暂时没有订单完成的消息，监听等待100ms
2017-03-13 11:21:13.516  INFO 15636 --- [      Thread-10] com.stefan.web.async.MockQueue           : 模拟订单完成返回消息
2017-03-13 11:21:13.559  INFO 15636 --- [       Thread-7] com.stefan.web.async.QueueListener       : 模拟拉取消息队列的完成订单消息后清空队列中的该消息
2017-03-13 11:21:13.563  INFO 15636 --- [       Thread-7] com.stefan.web.async.QueueListener       : 暂时没有订单完成的消息，监听等待100ms
```

## 异步处理配置

在WebMvcConfigurerAdapter中除了addInterceptors()注册同步请求拦截器方法外，还支持注册拦截器拦截异步处理的请求.

```java
@Configuration
public class WebConfig extends WebMvcConfigurerAdapter {

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(...);
    }

    @Override
    public void configureAsyncSupport(AsyncSupportConfigurer configurer) {
        //分别对以上两种异步方式请求的拦截支持
        configurer.registerCallableInterceptors(...);
        configurer.registerDeferredResultInterceptors(...);
        //设置异步请求的超时时间
        configurer.setDefaultTimeout(6000);
        //setTaskExecutor()方法用于设置可重用的线程池，
        //因为Runable异步方式默认使用Spring的简单异步线程池处理的，不会重用池中的线程，而是每次被调用都会新开线程
        configurer.setTaskExecutor(...);
    }
}
```