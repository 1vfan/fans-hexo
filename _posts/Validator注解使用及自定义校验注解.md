---
title: Hibernate Validator及自定义校验注解
date: 2017-06-03 19:43:01
tags:
- SpringBoot
- Spring
- Annotation
- Validator
- RESTful
categories: 
- SSM
---

记录日常开发中基于注解校验字段以及如何自定义一个校验注解

<!--more-->

## 常用的校验注解

Bean Validation规范内置的校验注解

|Annotation|支持类型|作用|
|---|---|---|
|@Valid|非初级类型|递归地对注解对象进行校验：若为数组或集合则递归校验；若为map则对值部分校验|
|@NotNull|any type|对应字段不允许为null|
|@Past|Date|必须是过去的日期|
|@Future|Date|必须是将来的日期|
|@Max(value)|数值|必须<=value值|
|@Min(value)|数值|必须>=value值|
|@Digits(integer, fraction)|数值|校验整数位和小数位|
|@Size(min, max)|String、数组、集合、map|元素大小在指定范围内，前提是该对象必须要有size()方法(String类型除外)|
|@Pattern(regex, flag)|String|必须符合指定的正则regex|
|||

Hibernate Validator拓展的校验注解

|Annotation|支持类型|作用|
|---|---|---|
|@NotEmpty|String、数组、集合、map|不能为null或空值，功能强于@NotNull|
|@NotBlank|String|不为null、空值或全空格，功能强于@NotEmpty|
|@Length(min, max)|String|等同于@Size，但只支持String|
|@Range(min, max)|数值、String、byte|判断数值的范围，还支持字符串、字节等类型|
|@Email|String|校验邮件地址|
|||


## 自定义注解

### 成员属性约束注解

User实例对象，分别在字段属性上添加约束注解

```java
public class User {
	
	public interface UserSimpleView {};
	public interface UserDetailView extends UserSimpleView {};
	
	private String id;
	
	@UserConstraint(message = "自定义验证注解测试")
	private String userName;
	
	@NotBlank(message = "密码不能为空")
	private String password;
	
	@Past(message = "生日必须是过去的时间")
	private Date birthday;

    getter/setter...
}
```

自定义约束注解UserConstraint，指定约束校验器

```java
@Target({ElementType.METHOD, ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy={UserConstraintValidator.class})
public @interface UserConstraint {
	
    //message后面可自行添加default "验证约束信息"
    String message();
		
    Class<?>[] groups() default { };

    Class<? extends Payload>[] payload() default { };
}
```

定义约束校验器，返回false则将message中的校验信息存入BindingResult（继承自Errors）中

```java
public class UserConstraintValidator implements ConstraintValidator<UserConstraint, String> {

    public void initialize(UserConstraint constraintAnnotation) {
        System.out.println("user constraint init......");
    }

    public boolean isValid(String value, ConstraintValidatorContext context) {
        if(value == null){
            System.out.println("---------isValid value = null");
            return false;
        }
        boolean isValid = value.length() <= 10;
        if(!isValid){
            System.out.println("---------userName长度不能超过10");
            return false;
        }
        return true;
    }
}
```

UserController模拟Controller更新服务，接收User对象参数并返回违反校验规则的错误信息

```java
@RestController
@RequestMapping("/user")
public class UserController {
	
    @PutMapping
    public User updateUser(@Valid @RequestBody User user, BindingResult errors) {
        System.out.println("模拟updateUser服务返回user");
        if(errors.hasErrors()) {
            errors.getAllErrors().stream().forEach(error -> {
                System.out.println("---------errorMsg:" + error.getDefaultMessage());
            });
        }
        return user;
    }
}
```

JUnit测试PutMapping验证更新操作传入的值，使用MockMvc构造一个伪造的mvc环境用于测试

```java
@SpringBootTest
@RunWith(SpringRunner.class)
public class UserConstraintTest {
	
    @Autowired
    private WebApplicationContext wac;
	
    private MockMvc mockMvc;
	
    @Before
    public void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac).build();
    }
	
    @Test
    public void userValidateTest() throws Exception{
        String content = "{\"userName\":\"StefanStefanStefan\",\"password\":null}";
        String result = mockMvc.perform(put("/user").contentType(MediaType.APPLICATION_JSON_UTF8)
                .content(content))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        System.out.println("---------result:"+result);
    }
}
```

测试返回结果

```bash
user constraint init......
---------userName长度不能超过10
模拟updateUser服务返回user
---------errorMsg:自定义验证注解测试
---------errorMsg:密码不能为空
---------result:{"id":null,"userName":"StefanStefanStefan","password":null,"birthday":null}
```

### 类级别约束注解

基本流程同上一致，以PersonConstraint为例，@PersonConstraint作用在类上，@Target属性为ElementType.TYPE，ConstraintValidator<T, T>后使用Person类

```java
@PersonConstraint
public class Person {
    ....
}


@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy={PersonConstraintValidator.class})
public @interface PersonConstraint {
	
    String message();
		
    Class<?>[] groups() default { };

    Class<? extends Payload>[] payload() default { };
}


public class UserConstraintValidator implements ConstraintValidator<PersonConstraint, Person> {

    public void initialize(PersonConstraint constraintAnnotation) {
        System.out.println("Person constraint init......");
    }

    public boolean isValid(Person value, ConstraintValidatorContext context) {
        ......
        return true;
    }
}
```

