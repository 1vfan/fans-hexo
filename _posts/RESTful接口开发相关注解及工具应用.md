---
title: RESTful接口开发相关注解及工具
date: 2017-06-02 19:43:01
tags:
- SpringBoot
- Spring
- SpringMVC
- RESTful
categories: 
- SSM
---

记录Spring+SpringMVC+SpringBoot的初步探索

<!--more-->



## 

## Controller

```java
@RestController
@RequestMapping("/user")
public class SpringSecurityController {

    @GetMapping
    public User queryUser(String id) {
        System.out.println("模拟query操作");
        User user = new User();
        user.setId("4");
        return user;
    }

    @PostMapping("/{id:\\d+}")
    public User addUser(@RequestBody User user) {
        System.out.println("模拟add操作");
        User user = new User();
        user.setUserName("stefan");
        return user;
    }

    @PutMapping("/{id:\\d+}")
    public User updateUser(@RequestBody User user) {
        System.out.println("模拟update操作");
        User user = new User();
        user.setUserName("stefan");
        return user;
    }

    @DeleteMapping("/{id:\\d+}")
    public void deleteUser(@PathVariable String id) {
        System.out.println("模拟delete操作");
    }
}
```



## Junit测试

```java
@SpringBootTest
@RunWith(SpringRunner.class)
public class SpringSecurityTest {

    @Autowired
    private WebApplicationContext wac;

    private MockMvc mockMvc;

    @Before
    public void setup() {
        mockMvc = MockMvcBuilders.MockMvcBuilders.webAppContextSetup(wac).build();
    }

    //post test
    @Test
    public void createTest() throws Exception {
        String content = "{\"username\":\"stefan\",\"password\":\"123456\",\"birthday\":" + new Date().getTime() + "}";
        String result = mockMvc.perform(post("/user/1")
            .contentType(MediaType.APPLICATION_JSON_UTF8)
            .content(content))
            .andExpect(status().isOk())
            .andExpect(jsonPath("userName").value("stefan"))
            .andReturn().getResponse().getContentAsString();
        System.out.println(result);
    }

    //get test
    @Test
    public void queryTest() throws Exception {
        String result = mockMvc.perform(get("/user")
            .contentType(MeidaType.APPLICATION_JSON_UTF8))
            .andExpect(status().isOk())
            .andExpect(jsonPath("id").value("4"))
            .andReturn().getResponse().getContentAsString();
        System.out.println(result);
    }

    //put test
    @Test
    public void updateTest() throws Exception {
        String content = "{\"username\":\"stefan\",\"password\":\"123456\",\"birthday\":" + new Date().getTime() + "}";
        String result = mockMvc.perform(put("/user/1")
            .contentType(MediaType.APPLICATION_JSON_UTF8)
            .content(content)
            .andExpect(status().isOk())
            .andExpect(jsonPath("userName").value("stefan"))
            .andReturn().getResponse().getContentAsString());
        System.out.println(result);
    }

    //delete test
    @Test
    public void deleteTest() throws Exception {
        mockMvc.perform(delete("/user/1")
            .contentType(MediaType.APPLICATION_JSON_UTF8))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
    }

    //delete fail test
    @Test
    public void delete() throws Exception {
        mockMvc.perform(delete("/user/a")
            .contentType(MediaType.APPLICATION_JSON_UTF8))
            .andExpect(status().is4xxClientError());
    }
}
```

## swagger自动生成html文档

swagger核心依赖以及控制台管理界面UI

```xml
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-swagger2</artifactId>
    <version>2.7.0</version>
</dependency>
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-swagger-ui</artifactId>
    <version>2.7.0</version>
</dependency>
```

添加@EnableSwagger2注解

```java
/**
 * @author stefan
 */
@SpringBootApplication
@EnableSwagger2
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
```

可通过注解标识接口名（@ApiOperation）和传入返回参数（@ApiParam、@ApiModelProperty）

```java
public class User {
	
    private String id;

    @ApiModelProperty(value = "用户姓名")
    private String name;
}
```

```java
@GetMapping("/{id:\\d+}")
@ApiOperation(value = "查询用户信息服务"))
public User getUserInfo(@ApiParam("用户id") @PathVariable String id) {
    User user = new User();
    ....
    return user;
}
```

访问 http://localhost:9080/swagger-ui.html 查看接口文档及便捷的测试接口


## WireMock快速伪造RESTful服务

在后端RESTful接口未开发完成之前，供不同客户端调用模拟的接口url返回特定统一json数据结果. 

访问官网 http://wiremock.org/docs/running-standalone/ 下载保存到D:/wiremock-standalone-2.11.0.jar，命令行运行 java -jar D:/wiremock-standalone-2.11.0.jar --port 9080 启动WireMock的服务器，然后编写client端代码添加模拟的服务

```xml
<dependency>
    <groupId>com.github.tomakehurst</groupId>
    <artifactId>wiremock</artifactId>
</dependency>
```

```json
模拟请求返回结果：

/mock/response/01.txt
{
    "id":"10001",
    "name":"stefan"
}

/mock/response/02.txt
{
    "lon":121.333333,
    "lat":29.3333333
}
```

每次改动需要重启client端以刷新服务器端

```java
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.springframework.core.io.ClassPathResource;

import com.github.tomakehurst.wiremock.client.WireMock;

/**
 * @author stefan
 */
public class MockServer {

    public static void main(String[] args) throws IOException {
        //client连接服务端port
        WireMock.configureFor(9080);
        //在重启client端时清空之前发布在服务器端的模拟服务
        WireMock.removeAllMappings();
        //发布两个模拟服务
        mock("/search/1", "01");
        mock("/search/2", "02");
    }

    private static void mock(String url, String file) throws IOException {
        //加载文件src/main/resources/mock/response/*.txt
        ClassPathResource resource = new ClassPathResource("mock/response/" + file + ".txt");
        //文档内容读入转成String
        String content = StringUtils.join(FileUtils.readLines(resource.getFile(), "UTF-8").toArray(), "\n");
        //WireMock.get表示get请求，根据匹配的url请求返回文档中内容
        WireMock.stubFor(WireMock.get(WireMock.urlPathEqualTo(url))
                .willReturn(WireMock.aResponse().withBody(content).withStatus(200)));
    }
}
```

通过 http://localhost:9080/search/1 和 http://localhost:9080/search/2 便能获得自定义的json结果


## 注解

1.@PathVariable

@PathVariable : 映射接口url片段到方法的参数

地址栏  /user/1
方法上  /user/{id}
传参    (@PathVariable String id)


带正则@PathVariable

地址栏  /user/1
方法上  /user/{id://d+}
传参    (@PathVariable String id)


2.JsonView控制Json输出内容

使用步骤：
* 使用接口声明多个视图

用户简单视图
public interface UserSimpleView {};
用户详细视图
public interface UserDatilView extends UserSimpleView {};

* 在值对象的get方法上指定视图
由于UserDatilView继承UserSimpleView，所以展示被UserDatilView指定的字段的同时会展示UserSimpleView字段

@JsonView(UserDetailView.class)
public String getPassword() {
    return password;
}

@JsonView(UserSimpleView.class)
public String getUserName() {
    return userName;
}

* 在Controller方法上指定视图
@GetMapping("/user/{id}")
@JsonView(User.UserSimpleView.class)
public User query(@PathVariable String id) {

}

返回：{"userName":"stefan"}

@GetMapping("/user/{id://d+}")
@JsonView(User.UserDatilView.class)
public User getInfo(@PathVariable String id) {

}

返回：{"userName":"stefan", "password":"123456"}

3.RestController

标明此Controller提供Restful API


4.RequestMapping及其变体

映射http请求url到java方法

5.RequestParam

映射请求参数到java方法的参数

public User queryByName(@RequestParam(name="userName", required = false, defaultValue="stefan") String newUserName) {
    //设为flase后http请求中就不必带有userName参数
}

6.PageableDefault

指定分页参数默认值，如果前台未传入相关分页，则使用@PageableDefault规定的默认参数，需要与SpringData整合

(@PageableDefault(size=10, page=3, sort="userName,asc") Pageable pageable)


## 自定义全局异常处理


