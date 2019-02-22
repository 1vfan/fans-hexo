---
title: Ajax跨域访问解决方案之JSONP
date: 2017-02-17 22:43:01
tags:
- Ajax
- JSONP
- struts2
categories: 
- SSM
---

记录js中跨域访问限制解决方案以及struts2作为服务端该如何配置

<!--more-->

## 同源策略

在JavaScript中，有一个很重要的安全性限制，被称为同源策略（Same- Origin Policy），即JavaScript只能访问 与包含该js文档或脚本 在同一域名下的资源.

何谓同源同域：就是协议、域名、端口号都必须相同（https://1vfan.github.io）.

何谓跨域：一个域名下的文件去访问另一个不同域名（或子域）下的资源.

## JSONP

JSON（JavaScript Object Notation）是一种轻量级的数据交换格式，易于机器解析和生成(网络传输速度快).

JSONP（JSON with Padding）用于解决主流浏览器的跨域数据访问限制：同源策略跨域请求会被限制，但Web页面调用js文件却不受跨域的影响，且拥有“src”这个属性的标签（script、img、iframe）都拥有跨域的能力，因此可用HTML的script标签来进行跨域请求，并在服务器端响应中返回要执行的script代码而非JSON数据（可以直接使用JSON传递js对象，即在跨域的服务端生成JSON数据，然后包装成script脚本回传），就解决了跨域访问限制.

总结：JSON是一种轻量级的数据交换格式，类似xml；JSONP是一种使用JSON数据的方式，返回的不是JSON对象，是包含JSON对象的js脚本.

## 代码实现

该协议的一个要点就是允许用户传递一个callback参数给服务端，然后服务端返回数据时会将这个callback参数作为函数名来包裹住JSON数据，这样客户端就可以随意定制自己的函数来自动处理返回展示数据了.

### struts2.xml

```bash
<struts>
	<constant name="struts.i18n.encoding" value="utf-8"></constant>
	<constant name="struts.custom.i18n.resources" value="global" />
	<constant name="struts.multipart.maxSize" value="20971520" />
	<constant name="struts.devMode" value="true" />

	<package name="json" extends="json-default">
		<result-types>
			<result-type name="json" class="org.apache.struts2.json.JSONResult"></result-type>
		</result-types>
		
		<action name="inXzq" class="com.zjjzfy.bgis.manager.actions.inXzqAction" method="inXzq">
            <!-- 设置callback参数 -->
			<param name="callbackParameter">jsoncallback</param>
			<param name="excludeNullProperties">true</param>
			<result name="success" type="json"></result>
		</action>
	</package>
</struts>
```

### Ajax

```bash
function inXzq(lon, lat) {
    var inXzqObj = {
        "lon": lon,
        "lat": lat
    };
    $.ajax({
        url: "http://serverIP:serverPort/bgis-manager/inXzq.action",
        type: "get",
        data: {
            "json": JSON.stringify(inXzqObj)
        },
        dataType: "jsonp",
        jsonp: "jsoncallback",
        success: function(result) {
            if (result.opResult == 'success') {
                //.....	
            } else {
                showErrMsg(result.opMsg);
            }
        },
        error: function(err) {
            showErrMsg(err);
        }
    });
}
```