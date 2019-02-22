---
title: SpringSecurity
date: 2017-06-02 19:43:01
tags:
- SpringBoot
- SpringSecurity
categories: 
- SSM
---

记录SpringSecurity+SpringBoot的实现认证、授权、防护等方面的应用

<!--more-->

# SpringSecurity的基本原理

SpringSecurity的核心其实是下图中的一组Filter（过滤器链），所有访问REST服务的请求都要经过这一组过滤器链

![png1](/img/SpringSecurity/SpringSecurity.png)

绿色的一组过滤器作为核心过滤器作用是身份验证，不同过滤器代表不同的认证方式，如表单验证方式、http basic验证方式

```java
@Configuration
public class SecurityConfig extends WebSecurityConfigurerAdapter{
	
    //重写configure(HttpSecurity http)方法，定义身份验证方式
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        
        //默认http basic验证
        //http.httpBasic()

        //表单验证：所有请求都必须通过身份认证才能成功访问
        http.formLogin()
            .and()
            .authorizeRequests()
            .anyRequest()
            .authenticated();
    }
}
```

FilterSecurity Interceptor是整个过滤器链的最后一环，我们自定义的业务规则都会在这个过滤器中执行判断，若通过规则便可成功调用REST服务，若不通过（如未完成身份校验、不符合VIP用户权限等等）便会抛出对应的异常；而Exception Translation Filter作为异常捕获过滤器会捕获FilterSecurity Interceptor中抛出的异常，然后根据不同异常做相应的处理（如未完成身份登陆，则会根据之前规定的身份验证方式跳转到相应的登陆界面）

## 问题小结

* Caused by: java.lang.IllegalArgumentException: No Spring Session store is configured: set the 'spring.session.store-type' property

解决方法：SpringBoot项目的application.yml配置文件中添加

```yml
spring: 
    session: 
        store-type: none
```

## 身份验证

在使用SpringSecurity框架后所有的RESTful接口默认都被保护起来，当用户请求时需要身份验证，否则报401

```json
There was an unexpected error (type=Unauthorized, status=401).
Full authentication is required to access this resource

{
    "timestamp": 1508805802173,
    "status": 401,
    "error": "Unauthorized",
    "message": "Bad credentials",
    "path": "/xxx"
}
```

解决方法一：SpringBoot项目的application.yml配置文件中添加以下配置，相当于屏蔽SpringSecurity的身份验证

```yml
security:
  basic:
    enabled: false
```

解决方法二：输入默认用户名user及项目启动时提供的密码Using default security password:592e4ff3-5812-43ce-83ad-c409c2167142

```bash
用户名：user
密码：592e4ff3-5812-43ce-83ad-c409c2167142
```

当然这种内置的默认http basic身份校验不能满足实际开发需要，我们需要去覆盖并配置自定义身份校验

## 







