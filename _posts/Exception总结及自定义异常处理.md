---
title: Exception总结及自定义异常处理
date: 2017-03-19 19:43:01
tags:
- Exception
- Spring
- SpringBoot
- RESTful
categories: 
- SSM
---

记录Java日常开发中异常的处理方案总结以及自定义异常的使用

<!--more-->

# 异常

Java异常类之间的继承关系图

![png1](/img/exception/20171024_1.png)

java非正常情况分为异常和错误，二者都继承Throwable父类，Error一般与虚拟机有关（系统崩溃、线程死锁、虚拟机错误、java.lang.OutOfMemoryError等），通常应用程序无法处理这些错误，JVM一般会终止线程结束程序运行.

异常又分为检查异常和非检查异常，规定所有的RuntimeException及其子类的实例称为运行时异常即非检查异常，此类异常需要我们修正代码，而不是通过异常捕获处理；一般的运行时异常包括如下：

* NullPointerException 空指针异常

```java
String str = null;
System.out.println(str.length());
```

* ArrayIndexOutOfBoundsException 数组下标越界异常

```java
int[] arr = {1, 2, 3}; 
for(int i=0, i<=3, i++) {
    System.out.println(arr[i]);
}
``` 

* ClassCastException 数据转换异常

```java
class Animal {}

class Dog extends Animal {}

class Cat extends Animal {}

class Test {
    public static void main(String[] args) {
        Animal d1 = new Dog();
        Cat d2 = (Cat)d1;
    }
}
```

* ArithmeticException 算术异常

```java
int a = 100;
int b = 0;
int result = a / b;
``` 

除此之外其他异常的实例称为检查异常，java认为检查异常都是可以被修复的异常（读取文件时文件不存在引发的FileNotFoundException、连接数据库时连接失败导致的SQLException、），因此若程序没有显式处理检查异常（定义该方法时声明抛出 或 捕获并处理），则无法通过编译.

## throw throws

throws出现在方法函数头，对可能抛出异常的声明，但不一定会发生这些异常；而throw出现在函数体，是抛出异常的一个动作，执行throw一定会抛出了该异常对象；二者只是抛出或者可能抛出异常，都不会由函数去处理异常，而是由函数的上层调用处理.

## finally

finally在try中的return之后及在返回主调函数之前执行，无论是否出现异常或try和catch中有无return，finally块中代码都会执行，所以尽量在finally块中释放占用的资源（关闭文件、数据库连接等），finally中最好不要包含return，否则返回会覆盖try或catch中return值。

## 多线程

Java中的异常是线程独立的，在多线程环境中，没有被任何代码处理的异常仅仅会导致异常所在的线程结束，每一个线程都是一个独立的执行流，独立的函数调用栈，不会直接影响到其它线程的执行。

## 异常封装

对Java API提供的偏底层信息的异常进行封装给用户返回易懂的错误提示可以提高系统友好性；同时封装异常建立异常容器，可以抛出一个方法中存在的多个异常，以弥补Java自身异常机制的缺陷.

## 注意

一个catch捕获多异常时，如下编译时会报错：The exception FileNotFoundException is already caught by the alternative IOException. 

```java
public class Test {
    public static void main(String[] args) {         
        try {             
            method();
        }catch (FileNotFoundException | IOException e) {
            e.printStackTrace();
        }
    }
 
    public static void method() throws IOException, FileNotFoundException {
    
    }
}
```

因为FileNotFoundException是IOException的子类，需要分开catch或者去掉子类，需要注意的是子类FileNotFoundException必须要在父类IOException前，否则编译报错：Unreachable catch block for FileNotFoundException.

```java
public class Test {
    public static void main(String[] args) {         
        try {             
            method();
        }catch (FileNotFoundException e) {
            e.printStackTrace(); 
        }catch (IOException  e) {
            e.printStackTrace(); 
        }
    }
 
    public static void method() throws IOException, FileNotFoundException {
    
    }
}
```

下面代码编译会报错：Unreachable catch block for JAXBException. 因为JAXBException是检查异常，method()应该抛出此异常供调用方法catch捕获，而不会从try子句中抛出，所以需要移除JAXBException的catch子句；而NullPointerException是非检查异常，所以它的异常捕获是有效的.

```java
public class Test {
    public static void main(String[] args) {
        try {
            method();
        }catch (IOException e) {
            e.printStackTrace();
        }catch (JAXBException e){
            e.printStackTrace();
        }catch (NullPointerException e){
            e.printStackTrace();
        }catch (Exception e){
            e.printStackTrace();
        }
    }       
    
    public static void method() throws IOException{
 
    }
}
```

以下代码可以正确编译，即使method1()在throws中未声明，也能捕获到一般异常或者非检查异常；同样method2()在throws声明了非检查异常，程序中也不一定要处理这个异常.

```java
public class Test {
    public static void main(String[] args) {
        try{
            method1();
        }catch(NullPointerException e){
            e.printStackTrace();
        }catch(Exception e){
            e.printStackTrace();
        }
        method2();     
    }
 
    public static void method1(){
 
    }
 
    public static void method2() throws NullPointerException{
    
    }
}
```

以下不能被编译，因为父类中method1()签名与子类中的method1()签名不同；可以修改子类的方法签名使之与超类相同，也可以移除子类中throws声明.

```java
public class Test {
    public void method1() throws IOException {
 
    }
 
    public void method2() throws NullPointerException {
    
    }  
}

public class Test1 extends Test {
    public void method1() throws Exception {

    }
        
    public void method2() throws RuntimeException {
        
    } 
}
```

## ARM

Java7中ARM(Automatic Resource Management，自动资源管理)特征和多个catch块的使用

```java
Java7新特性：一个catch子句中可以捕获多个异常，减少catch块的使用以及记录异常的多余代码，使代码更简洁；示例如下：

catch(IOException | SQLException | Exception ex){
    logger.error(ex);
    throw new MyException(ex.getMessage());
}

Java7新特性：在try子句中能创建一个资源对象，当程序执行完try-catch之后，运行环境自动关闭该资源，类似于finally；示例如下：

try (MyResource mr = new MyResource()) {
    System.out.println("MyResource created in try-with-resources");
} catch (Exception ex) {
    logger.error(ex);
    ex.printStackTrace();
}
```

# RESTful API 错误处理

## SpringBoot中默认的错误处理机制

BasicErrorController作为SpringBoot内部默认的处理异常的控制器，专门处理/error的请求，当请求头中包含"text/html"时，执行errorHtml()，否则执行error().

```java
@Controller
@RequestMapping("${server.error.path:${error.path:/error}}")
public class BasicErrorController extends AbstractErrorController {

    //请求头中包含"text/html"，返回HTML页面
    @RequestMapping(produces = "text/html")
    public ModelAndView errorHtml(HttpServletRequest request, HttpServletResponse response) {
        ....
    }

    //请求头中不包含"text/html"，返回json数据
    @RequestMapping
    @ResponseBody
    public ResponseEntity<Map<String, Object>> error(HttpServletRequest request) {
        ....
    }
}
```

对于web端和移动端请求结果有所不同，web端返回HTML的错误页面，移动端则返回json数据

```bash
Whitelabel Error Page

This application has no explicit mapping for /error, so you are seeing this as a fallback.

Tue Oct 24 09:24:40 CST 2017
There was an unexpected error (type=Not Found, status=404).
No message available
```

```json
{
    "timestamp": 1508808254939,
    "status": 404,
    "error": "Not Found",
    "message": "No message available",
    "path": "/xxx"
}
```

# SpringBoot自定义异常处理

## 自定义异常的好处

使用自定义异常类可以统一对外展示异常的方式；继承相关异常来抛出处理后的异常信息可以隐藏底层异常，抛出我们想要抛出的直观信息，而不是输出堆栈信息；还有些错误其实是符合Java语法的，但不符合系统中的业务逻辑，可以通过自定义异常来处理；在某些校验问题需要直接结束当前请求时，便可通过抛出自定义异常来结束，若项目中使用了SpringMVC较新版本有控制器增强，可通过@ControllerAdvice注解写一个控制器增强类来拦截该自定义异常并响应给前端相应信息，如下代码示例.

## 自定义特定异常状态码页面

只对浏览器发出的请求异常时返回特定错误页面，对app发出的请求不起作用

具体步骤：在src/main/resources路径下新建/resources/error/子目录，然后新建404.html、500.html等，当在浏览器发请求抛出异常时，SpringBoot会去加载显示新建的对应状态码的页面信息


## 自定义特定json异常数据返回

一般继承Exception类或其任何子类来实现自己的自定义异常类，自定义异常类可以有自己的变量和方法来传递错误代码或其它异常相关信息；如参数id是无法包含在json中返回给前台的，需要我们重新定义封装异常类

```java
public class UserNotExistException extends RuntimeException {
	
	private String id;
	
	public UserNotExistException(String id) {
		super("user not exist");
		this.id = id;
	}

	public String getId() {
		return id;
	}
	public void setId(String id) {
		this.id = id;
	}
}
```

创建一个全局控制器增强类捕获所有控制器中的异常，在方法上指定处理的特定异常，那么在方法体中就可以处理该异常的相关信息.

```java
@ControllerAdvice //不处理http请求，只负责处理其他控制器抛出的异常
public class ControllerExceptionHandler {

	@ExceptionHandler(UserNotExistException.class) //规定以下方法处理什么异常
	@ResponseBody //return json
	@ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR) //httpStatusCode:500
	public Map<String, Object> handleUserNotExistException(UserNotExistException ex) {
		//按自定义json格式返回异常数据
        Map<String, Object> result = new HashMap<>();
		result.put("id", ex.getId());
		result.put("message", ex.getMessage());
		return result;
	}
}
```

测试该自定义异常

```java
@RestController
@RequestMapping("/user")
public class UserController {
	
	@GetMapping("/{id:\\d+}")
	@JsonView(User.UserDetailView.class)
	public User getInfo(@ApiParam("用户id") @PathVariable String id) {
        System.out.println("模拟进入getInfo服务");
		throw new UserNotExistException(id);
	}
}
```

测试并返回结果：http://localhost:9080/user/111

```json
{
    "id": "111",
    "message": "User Not Exist"
}
```