---
title: Filter、Interceptor、Aspect拦截Rest服务
date: 2017-07-03 19:43:01
tags:
- SpringBoot
- Spring
- AOP
- Filter
- Interceptor
- RESTful
categories: 
- SSM
---

记录使用配置类方式Filter、Interceptor、Aspect各自拦截Rest服务的实现方案

<!--more-->

# Filter

Filter实现javax.servlet.Filter接口，是JavaEE规范里定义的，可视为Servlet的"增强版"，二者在web.xml中配置相似，生命周期相同，Filter随web应用启动而启动且只初始化一次，web应用停止或重新部署便销毁；Filter可以负责拦截多个请求或响应，同样一个请求或响应也可被多个Filter拦截（过滤器链）.

## Filter用处

项目系统中Rest请求服务往往会进行一些通用的处理（如权限控制、日志记录等），我们需要把通用的处理放到Filter中，以防止部分代码重复问题.

过滤用户非法请求的用户授权Filter（判断用户未登录后过滤其他请求url，重定向到指定登陆页面）

详细记录特殊请求的日志Filter

使浏览器不缓存页面的Filter

负责对非标准编码的请求解码Filter

## 整体拦截流程

Filter对负责拦截的用户请求做预处理，在HttpServletRequest到达Servlet之前，拦截、检查、修改HttpServletRequest.

Filter将请求交给Servlet（或Action、Controller）进行处理并产生响应，Filter也可对用户请求生成相应，但很少这么做.

Filter对服务器响应进行后处理，在HttpServletResponse到达客户端之前，拦截、检查、修改HttpServletResponse.

## 自己写的Filter

自己写的Filter无论通过哪种方式都可以起作用，通过注解方式相对简便

* 传统web.xml配置方式 + Filter类

```java
public class TimeFilter implements javax.servlet.Filter {

    public void init(FilterConfig arg0) throws ServletException {
        System.out.println("time filter init");
    }

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        System.out.println("time filter start");
        long start = new Date().getTime();
        chain.doFilter(request, response);
        System.out.println("time filter 耗时:"+ (new Date().getTime() - start));
        System.out.println("time filter finish");
    }

    public void destroy() {
        System.out.println("time filter destroy");
    }
}
```

```xml
<filter>
    <filter-name>timeFilter</filter-name>
    <filter-class>com.stefan.TimeFilter</filter-class>
</filter>
<filter-mapping>
    <filter-name>timeFilter</filter-name>
    <url-pattern>/*</url-pattern>
</filter-mapping>
```

* Filter特定注解声明配置

```java
@WebFilter(filterName="timeFilter",urlPatterns={"/*"})
public class TimeFilter implements javax.servlet.Filter {
    ...
}
```

* SpringBoot中通过声明Spring注解配置

```java
@Component
public class TimeFilter implements javax.servlet.Filter {
    ...
}
```

## 引用第三方框架Filter

引用第三方框架的Filter无法通过声明注解将Filter加入到项目中，同时在SpringBoot项目中又没有web.xml文件可配置，需要通过配置类的方式来注册Filter

```java
//假设TimeFilter为第三方框架Filter
public class TimeFilter implements javax.servlet.Filter {
    ...
}
```

WebConfig配置类就相当于传统的web.xml中的配置

```java
@Configuration
public class WebConfig {
    @Bean
    public FilterRegistrationBean timeFilter() {	 
        FilterRegistrationBean registrationBean = new FilterRegistrationBean();
        TimeFilter timeFilter = new TimeFilter();
        registrationBean.setFilter(timeFilter);
        List<String> urls = new ArrayList<>();
        urls.add("/*");
        registrationBean.setUrlPatterns(urls);
        return registrationBean;
    }
}
```

# Interceptor

拦截器是MVC框架（Struts2、SpringMVC）中重要组成部分，对框架而言都属于可插拔的设计，需要时在配置文件中应用即可，不需要时在配置文件中取消该拦截器，不论是否应用某个拦截器，对框架而言不会有任何影响.

## Struts2拦截器实现

Struts2绝大部分功能是通过拦截器来完成的，默认启用了大量通用的拦截器，只要在Action所在的package继承了struts-default包，这些拦截器就会起作用，以自定义权限控制拦截器为例，在authority包下的所有Action都会具有权限检查功能.

* struts.xml配置

```xml
<struts>
    <constant name="struts.il8n.encoding" value="utf-8" />
    <package name="authority" extends="struts-default">
        <interceptors>
            <!-- 定义一个名为authority的拦截器 -->
            <interceptor name="authority" class="com.stefan.interceptor.AuthorityInterceptor"/>
            <!-- 定义一个包含权限控制的拦截器栈 -->
            <interceptor-stack name="myDefault">
                <!-- 配置内建默认拦截器 -->
                <interceptor-ref name="defaultStack" />
                <!-- 配置自定义的拦截器 -->
                <interceptor-ref name="authority" />
            </interceptor-stack>
        </interceptors>
        <!-- 配置该包下的默认拦截器或拦截器栈 -->
        <default-interceptor-ref name="myDefault" />
        <!-- 定义全局result-->
        <global-results>
            <result name="login">/login.jsp</result>
        </global-results>
        <action ...></action>
    </package>

    <package name="json" extends="json-default">
        <result-types>
            <!-- json格式返回数据 -->
            <result-type name="json" class="org.apache.struts2.json.JSONResult"/>
        </result-types>
        <action ...></action>
    </package>
</struts>
```

* 拦截器类实现

```java
public class AuthorityInterceptor extends 
        com.opensymphony.xwork2.interceptor.AbstractInterceptor {
    
    @Override
    public String intercept(ActionInvocation invocation) throws Exception {
        //获取请求相关的ActionContext实例
        ActionContext ctx = invocation.getInvocationContext();
        Map session = ctx.getSession();
        //获取名为user的session属性
        Users user = (Users)session.get("user");
        //未登陆或用户不正确，返回重新登陆
        if(user != null && "stefan".equals(user)) {
            //若该拦截器后没有其他拦截器，则直接执行Action的被拦截方法
            return invocation.invoke();
        }
        return Action.LOGIN;
    }
}
```

## SpringMVC拦截器实现

Filter相较于Interceptor，缺点就是Filter是JavaEE规范里定义的，它只能接受Http的请求和响应中的参数，它并不知道请求是由哪个控制器的哪个方法处理的，而通过Interceptor的handler参数可以获取这些参数.

SpringMVC中的Interceptor实行链式调用，一个请求中可以同时存在多个Interceptor，按声明顺序执行，若preHandle()返回true继续调用直到完成最后一个Interceptor的preHandle()，然后去调用请求的Contorller方法，若preHandle()返回false则后续的Interceptor和Controller都不会执行.

```java
@Component
public class TimeInterceptor implements HandlerInterceptor {

	@Override
	public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
			throws Exception {
		System.out.println("preHandle");
        //获取处理请求的控制器类名和方法名
		System.out.println(((HandlerMethod)handler).getBean().getClass().getName());
		System.out.println(((HandlerMethod)handler).getMethod().getName());
		//不同于Filter的doFilter方法，Interceptor需要通过request来传递参数
        request.setAttribute("startTime", new Date().getTime());
        //return true （后面两个方法及控制器方法都会执行） return false （后面方法都不执行）
		return true;
	}

	@Override
	public void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler,
			ModelAndView modelAndView) throws Exception {
		System.out.println("postHandle");
		Long start = (Long) request.getAttribute("startTime");
		System.out.println("time interceptor 耗时:"+ (new Date().getTime() - start));
	}

	@Override
	public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex)
			throws Exception {
		System.out.println("afterCompletion");
		Long start = (Long) request.getAttribute("startTime");
		System.out.println("time interceptor 耗时:"+ (new Date().getTime() - start));
		//若控制器抛出异常，则不会执行postHandle()方法，可以通过ex参数获取
        //若控制器抛出异常已被异常处理器@ContorllerAdvice处理，则ex无法获取对应异常信息为null
        System.out.println("ex is "+ex);
	}
}
```

另一点与Filter不同的是，Interceptor实现HandlerInterceptor接口 + @Component注解的同时，还应该在配置类（继承WebMvcConfigurerAdapter）中注册该Interceptor.

```java
@Configuration
public class WebConfig extends WebMvcConfigurerAdapter {
	
    //因为已经通过@Component将TimeInterceptor注入到IOC中了
	@Autowired
	private TimeInterceptor timeInterceptor;
	
	@Override
	public void addInterceptors(InterceptorRegistry registry) {
		registry.addInterceptor(timeInterceptor);
	}
}
```

# Aspect

在DispatcherServlet中的doService()里调了doDispatch(request, response)，进入该方法查看发现，真正请求的参数组装是在applyPreHandle()之后的handle()方法中完成的，所以在interceptor的preHandle()中无法获取请求传入的参数，这就是interceptor的局限性，想要获取请求传入的参数，就需要使用Spring的核心组件AOP的切片 .

```java
//applyPreHandle就是在调用Interceptor中的preHandle方法
if (!mappedHandler.applyPreHandle(processedRequest, response)) {
    return;
}

// Actually invoke the handler
mv = ha.handle(processedRequest, response, mappedHandler.getHandler());

if (aysncManager.isConcurrentHandlingStarted()) {
    return;
}

applyDefaultViewName(processedRequest, mv);
mappedHandler.applyPostHandle(processedRequest, response, mv);
```

## 切片(类)

* 切入点(注解) 

在什么时候起作用？ 

@Around 涵盖了@Before、@After、@AfterThrowing（与interceptor中的preHandle、postHandle、afterCompletion类似）

在哪些方法上起作用？

@Around("execution(* com.stefan.web.controller.UserController.*(..))")

execution代表执行，*代表任何返回值，UserController代表作用的控制器，*(..)代表该控制下任何方法及任何参数.


* 增强(方法) 

起作用时执行的业务逻辑（如下handleControllerMethod()方法）

```java
@Aspect
@Component
public class TimeAspect {
	
	@Around("execution(* com.stefan.web.controller.UserController.*(..))")
	public Object handleControllerMethod(ProceedingJoinPoint pjp) throws Throwable {
		System.out.println("time aspect start");
        //通过ProceedingJoinPoint可以获取控制器方法的参数Object[] args
		Object[] args = pjp.getArgs();
		for (Object arg : args) {
			System.out.println("arg is "+arg);
		}
		long start = new Date().getTime();
        //类似Filter中的doFilter()，实际去调用处理请求的控制器方法
		Object object = pjp.proceed();
		System.out.println("time aspect 耗时:"+ (new Date().getTime() - start));		
		System.out.println("time aspect end");
		return object;
	}
}
```















