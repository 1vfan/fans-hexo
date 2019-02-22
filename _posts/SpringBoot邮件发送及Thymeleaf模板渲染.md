---
title: SpringBoot邮件发送及Thymeleaf模板渲染
date: 2017-06-18 10:23:09
tags:
- SpringBoot
- java
- Thymeleaf
categories: 
- SpringBoot
---

记录在SpringBoot项目中发送邮件及使用Thymeleaf渲染邮件模板

<!--more-->

# 前期准备

添加Mail依赖jar包

```bash
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-mail</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-thymeleaf</artifactId>
</dependency>
```

application.yml文件中添加Mail配置

```bash
spring:
  mail:
    default-encoding: UTF-8
    host: smtp.163.com   
    port: 25
    username: *********@163.com
    password: *********
    properties: 
      mail:
        smtp: 
          auth: true
          timeout: 30000
```

Junit测试邮件发送

```bash
@RunWith(SpringJUnit4ClassRunner.class)
@SpringBootTest(classes = Application.class)
public class ApplicationTests {

	private static Logger LOGGER = LoggerFactory.getLogger(ApplicationTests.class);

	@Autowired
	private JavaMailSender javaMailSender; 
	
	/**
	 * 测试邮件发送
	 * @throws Exception
	 */
	@Test
	public void sendSimpleMail() throws Exception{
		SimpleMailMessage mailMessage = new SimpleMailMessage();
		mailMessage.setFrom("***********@163.com");
		mailMessage.setTo("****@zjjzfy.com");
		mailMessage.setSubject("主题：内容测试");
		mailMessage.setText("测试内容");
		javaMailSender.send(mailMessage);
		LOGGER.info("---------------success-send-mail-------------");
	}
	
	/**
	 * 测试带附件的邮件发送
	 * @throws Exception
	 */
	@Test
	public void sendAttachmentsMail() throws Exception {
		MimeMessage mimeMessage = javaMailSender.createMimeMessage();
		MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, true); //true代表添加附件
		helper.setFrom("***********@163.com");
		helper.setTo("****@zjjzfy.com");
		helper.setSubject("主题：附件测试");
		helper.setText("测试内容");
		FileSystemResource docFile = new FileSystemResource(new File("D://test.docx"));
		FileSystemResource pngFile = new FileSystemResource(new File("D://test.png"));
		helper.addAttachment("附件-1.docx", docFile);
		helper.addAttachment("附件-2.png", pngFile);
		javaMailSender.send(mimeMessage);
		LOGGER.info("---------------success-send-mail-Attachments------------");
	}	
}
```

# 模板渲染

SpringBoot建议使用模板引擎，避免使用JSP；在SpringBoot中是约定大于配置，约定setTemplateName("SHEET")调用的就是src/main/resources/templates目录下的SHEET.html

```bash
//param就是邮件模板中需要的数据，通过类似EL的配置将对应key的value传到邮件模板中
Map<String, Object> param = new HashMap<String, Object>();
param.put("userName", mailSend.getSendUserId());
param.put("createDate", DateFormatUtils.format(mailSend.getUpdateTime(), "yyyy年MM月dd日"));
param.put("exportUrl", "www.baidu.com");
param.put("content", mailSend.getSendContent());

MailData mailData = new MailData();
mailData.setParam(param);
//对应在src/main/resources/templates目录下有个SHEET.html
mailData.setTemplateName("SHEET");
mailData.setSubject("【京东订单】");
mailData.setFrom("*************@163.com");
mailData.setTo(mailSend.getSendTo());

//渲染模板  并发送
generatorMailTemplateHelper.generatorAndSend(mailData);
```

渲染模板并发送

```bash
@Service
public class GeneratorMailTemplateHelper {

	@Autowired
	private TemplateEngine templateEngine;
	
	@Autowired
	private JavaMailSender mailSender;
	
	public void generatorAndSend(MailData data) throws Exception {
		//模板引擎的全局变量
		Context context = new Context();
		context.setLocale(Locale.CHINA);
		context.setVariables(data.getParam());
		String templateLoaction = data.getTemplateName();
		String content = templateEngine.process(templateLoaction, context);		
		data.setContent(content);
		//发送
		send(data);
	}

	private void send(MailData data) throws Exception {
        MimeMessage mime = mailSender.createMimeMessage();
        MimeMessageHelper mimeHelper = new MimeMessageHelper(mime, true, Const.CHARSET_UTF8);
        mimeHelper.setFrom(data.getFrom());
        mimeHelper.setTo(data.getTo());
        mimeHelper.setSubject(data.getSubject());
        mimeHelper.setText(data.getContent(), true);
        mailSender.send(mime);
	}
}
```

src/main/resources/templates目录下的Thymeleaf模板，如果缺少对应的标签如</body></html>，程序运行会报错

```bash
<html>
<head>
<title>订单信息</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<meta http-equiv="Content-Language" content="zh-CN"/>
<meta name="author" content="京东商城"/>
<style class="fox_global_style">
    div.fox_html_content { line-height: 1.5; }
    div.fox_html_content { font-size: 10.5pt; font-family: 微软雅黑; color: rgb(0, 0, 0); line-height: 1.5; }
    div.fp {margin-left:20pt;}
    div.sp {margin-left:20pt;}
</style>   
</head>
<body>
<div th:utext="${userName}">用户</div>
<div class="fp">您好</div>
<div><br /></div>
<div class="fp">您于<span th:utext="${createDate}"></span><span th:utext="${content}"></span>。</div>
<div class="fp">如需进行查看详细：<a href="${exportUrl}">点击此处下载</a>订单。</div>
<div><br /></div>

<div>
    <div class="fp">致</div>
    <div class="MsoNormal" >礼！</div>
</div>
</body>
</html>
```



