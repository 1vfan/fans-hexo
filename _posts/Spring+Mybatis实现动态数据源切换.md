---
title: Spring+Mybatis实现动态数据源切换
date: 2017-05-17 13:34:09
tags:
- Mybatis
- Spring
categories: 
- SSM
---
记录如何在Springboot+Spring+Mybatis+druid体系中配置基于annotation动态切换数据源的方案

<!--more-->



# 传统配置

![png1](/img/20170517_1.png)

传统配置会在Spring的ApplicationContext.xml中，一个数据源对应一个SqlSessionFactory，每一个Dao层的dao对应的SqlSessionFactory都是写死的；并且当我们项目中需要添加数据源时，又需要添加SqlSessionFactory

```bash
<beans>
        <aop:aspectj-autoproxy proxy-target-class="true" />

	<bean id="mysqlDataSource" class="org.apache.commons.dbcp.BasicDataSource">
		<property name="driverClassName" value="com.mysql.jdbc.Driver" />
		<property name="url" value="jdbc:mysql://xxx.xxx.xxx.xxx:3306/bgismanager?useUnicode=true&amp;characterEncoding=UTF-8" />
		<property name="username" value="root" />
		<property name="password" value="root" />
	</bean>
	<bean id="oracleDataSource" class="org.apache.commons.dbcp.BasicDataSource">
		<property name="driverClassName" value="oracle.jdbc.driver.OracleDriver" />
		<property name="url" value="jdbc:oracle:thin:@xxx.xxx.xxx.xxx:1521:orcl" />
		<property name="username" value="sde" />
		<property name="password" value="sde" />
	</bean>

	<bean id="mysqlTransactionManager"
		class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
		<property name="dataSource" ref="mysqlDataSource" />
	</bean>
	<bean id="oracleTransactionManager"
		class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
		<property name="dataSource" ref="oracleDataSource" />
	</bean>
	
	<tx:annotation-driven transaction-manager="mysqlTransactionManager" />
	<tx:annotation-driven transaction-manager="oracleTransactionManager" />

	<bean id="mysqlSqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
		<property name="dataSource" ref="mysqlDataSource" />
	</bean>
	<bean id="oracleSqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
		<property name="dataSource" ref="oracleDataSource" />
	</bean>
	
	<bean id="mysqlTestMapper" class="org.mybatis.spring.mapper.MapperFactoryBean">
		<property name="mapperInterface" value="com.zjjzfy.bgis.manager.interfaces.MysqlTestMapper" />
		<property name="sqlSessionFactory" ref="mysqlSqlSessionFactory" />
	</bean>
        <bean id="oracleTestMapper" class="org.mybatis.spring.mapper.MapperFactoryBean">
		<property name="mapperInterface" value="com.zjjzfy.bgis.manager.interfaces.OracleTestMapper" />
		<property name="sqlSessionFactory" ref="oracleSqlSessionFactory" />
	</bean>
</beans>
```

# 动态配置

动态切换数据源的实现原理就是扩展Spring的AbstractRoutingDataSource抽象类，该类充当DataSource的路由中介（相当于代理），它能有在运行时, 根据当前本地线程中的key值来动态切换到真正的DataSource上

![png2](/img/20170517_2.png)

## 添加DataSource

本篇基于Springboot配置，使用alibaba的开源druid数据源连接池在application.yml中配置数据源

```bash
# 自定义注解                
druid: 
    # 数据源名
    type: com.alibaba.druid.pool.DruidDataSource
    # 主数据源
    master:
        url: jdbc:mysql://192.168.154.20:3306/mail?characterEncoding=UTF-8&autoReconnect=true&zeroDateTimeBehavior=convertToNull&useUnicode=true
        driver-class-name: com.mysql.jdbc.Driver
        username: root
        password: root
        # 开始druid的配置
        ## 初始化
        initialSize: 5
        # 最小
        minIdle: 1
        # 最大已被废弃
        #maxIdle: 10
        # 最大存活
        maxActive: 100
        # 最大等待
        maxWait: 60000
        timeBetweenEvictionRunsMillis: 60000
        minEvictableIdleTimeMillis: 300000
        validationQuery: SELECT 1 FROM DUAL
        testWhileIdle: true
        testOnBorrow: false
        testOnReturn: false
        # 池化的配置
        poolPreparedStatements: true
        maxPoolPreparedStatementPerConnectionSize: 20
        # druid监控配置
        filters: stat,wall,log4j
        useGlobalDataSourceStat: true
    # 从数据源
    slave: 
        url: jdbc:mysql://192.168.154.21:3306/mail?characterEncoding=UTF-8&autoReconnect=true&zeroDateTimeBehavior=convertToNull&useUnicode=true
        driver-class-name: com.mysql.jdbc.Driver
        username: root
        password: root
        initialSize: 5
        minIdle: 1
        #maxIdle: 10
        maxActive: 100
        maxWait: 60000
        timeBetweenEvictionRunsMillis: 60000
        minEvictableIdleTimeMillis: 300000
        validationQuery: SELECT 1 FROM DUAL
        testWhileIdle: true
        testOnBorrow: false
        testOnReturn: false
        poolPreparedStatements: true
        maxPoolPreparedStatementPerConnectionSize: 20
        filters: stat,wall,log4j
        useGlobalDataSourceStat: true
```

## DataSource注入

本篇主要介绍使用annotation的形式来实现切换，所以首要任务是将数据源注入到Spring容器中管理

```bash
/**
 * http://localhost:9080/mail-producer-stefan-1.0/druid/
 * 最后通过浏览器查看druid控制台
 * @author lf
 *
 */
@Configuration  //让Spring容器识别当前类是配置类
@EnableTransactionManagement  //事务
public class DataSourceConfiguration {
	
	private static Logger LOGGER = LoggerFactory.getLogger(DataSourceConfiguration.class);

	@Value("${druid.type}") //利用注解将druid.type注入，以后改别的代码部分就不用修改，只需要修改yml就行
	private Class<? extends DataSource> dataSourceType; //自定义数据库连接池的数据源
	
	/**
	 * 通过@ConfigurationProperties(prefix = "druid.master")是Spring容器解析yml中以druid.master开头的配置
	 * DataSourceBuilder是一个autoconfigure，就配合容器将解析的druid.master的配置创建成一个以alibaba的连接池druid类型的dataSourceType（上述已经继承了DataSource）
	 * 最后起个名字masterDataSource，通过Bean注解交由Spring容器管理
	 * 下面的slaveDataSource同样如此，因此就向Spring容器中添加了两个数据源
	 * @return
	 * @throws SQLException
	 */
	@Bean(name = "masterDataSource")
	@Primary  //默认主数据源：可写可读
	@ConfigurationProperties(prefix = "druid.master") 
	public DataSource masterDataSource() throws SQLException{
		DataSource masterDataSource = DataSourceBuilder.create().type(dataSourceType).build();
		LOGGER.info("========MASTER: {}=========", masterDataSource);
		return masterDataSource;
	}
 
	@Bean(name = "slaveDataSource")
	@ConfigurationProperties(prefix = "druid.slave")
	public DataSource slaveDataSource(){
		DataSource slaveDataSource = DataSourceBuilder.create().type(dataSourceType).build();
		LOGGER.info("========SLAVE: {}=========", slaveDataSource);
		return slaveDataSource;
	}
  
	/**
	 * 自定义一个servlet注入到Spring容器中
	 * new StatViewServlet()是druid提供的，我们可以换成自己写的Servlet然后通过ServletRegistrationBean包装一下就能注入到容器中使用了
	 * druidServlet是druid监控台需要用到的一个servlet
	 * @return
	 */
	@Bean
	public ServletRegistrationBean druidServlet() {
  	
		ServletRegistrationBean reg = new ServletRegistrationBean();
		reg.setServlet(new StatViewServlet());
                //reg.setAsyncSupported(true);
		reg.addUrlMappings("/druid/*");
		reg.addInitParameter("allow", "localhost");
		reg.addInitParameter("deny","/deny");
                //reg.addInitParameter("loginUsername", "fan");
                //reg.addInitParameter("loginPassword", "fan");
		LOGGER.info(" druid console manager init : {} ", reg);
		return reg;
	}

	/**
	 * 自定义一个Filter注入到容器中
	 * new WebStatFilter()也是druid提供的一个 写好的filter,也可以自定义filter，我们使用FilterRegistrationBean包装一下就能注入到容器中
	 * @return
	 */
	@Bean
	public FilterRegistrationBean filterRegistrationBean() {
		FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
		filterRegistrationBean.setFilter(new WebStatFilter());
		filterRegistrationBean.addUrlPatterns("/*");
		filterRegistrationBean.addInitParameter("exclusions", "*.js,*.gif,*.jpg,*.png,*.css,*.ico, /druid/*");
		LOGGER.info(" druid filter register : {} ", filterRegistrationBean);
		return filterRegistrationBean;
	}
}
```

## 路由代理

DataSource注入后需要实现利用不同的DataSource动态的配置SqlSessionFactory，此时就需要AbstractRoutingDataSource这个路由代理类

```bash
public abstract class AbstractRoutingDataSource extends AbstractDataSource implements InitializingBean{

    protected DataSource determineTargetDataSource() {
            Assert.notNull(this.resolvedDataSources, "DataSource router not initialized");
            Object lookupKey = determineCurrentLookupKey();
            DataSource dataSource = this.resolvedDataSources.get(lookupKey);
            if (dataSource == null && (this.lenientFallback || lookupKey == null)) {
                dataSource = this.resolvedDefaultDataSource;
            }
            if (dataSource == null) {
                throw new IllegalStateException("Cannot determine target DataSource for lookup key [" + lookupKey + "]");
            }
            return dataSource;
        }

    protected abstract Object determineCurrentLookupKey();
}
```

通过源码看到AbstractRoutingDataSource继承自AbstractDataSource，而AbstractDataSource又是javax.sql.DataSource的子类，源码中的determineCurrentLookupKey()是AbstractRoutingDataSource类中的一个抽象方法，它的返回值就是所要用的数据源dataSource的key值，resolvedDataSource（这是个map，设置好后存入的）就通过这个key值从map中取出对应的DataSource（找不到就用默认配置的数据源），所以要扩展AbstractRoutingDataSource类，并重写其中的determineCurrentLookupKey()方法，来实现数据源的切换

## 封装Key值操作

重写determineCurrentLookupKey()方法的关键就在于给定在resolvedDataSource这个map中取值的key，为了保证在一次完整的数据操作过程中key值保持一致，使用ThreadLocal线程来封装数据源所对应的key（也就是下面的DataBaseType值）

```bash
/**
 * @author lf
 */
public class DataBaseContextHolder {
	
	public enum DataBaseType{
		MASTER,SLAVE
	}
	
	//ThreadLocal线程【key：当前线程，value:DataBaseType值】
	private static final ThreadLocal<DataBaseType> contextHolder = new ThreadLocal<DataBaseType>();
	
	public static void setDataBaseType(DataBaseType dataBaseType) {
		if(dataBaseType == null) throw new NullPointerException();
		contextHolder.set(dataBaseType);
	}
	
	public static DataBaseType getDataBaseType() {
		return contextHolder.get() == null ? DataBaseType.MASTER : contextHolder.get();
	}
	
	public static void clearDataBaseType() {
		contextHolder.remove();
	}
}
```

## 重写代理方法

继承AbstractRoutingDataSource，重写determineCurrentLookupKey()，给定key值类型

```
/**
 * @author lf
 */
public class ReadWriteSplitRoutingDataSource extends AbstractRoutingDataSource{
	/**
	 * 标明resolvedDataSource这个map中的key值类型
	 */
	@Override
	protected Object determineCurrentLookupKey() {
		return DataBaseContextHolder.getDataBaseType();
	}	
}
```

## 生成SqlSessionFactory

由于ReadWriteSplitRoutingDataSource继承自AbstractRoutingDataSource，所以它的超类也就是一个javax.sql.DataSource，所以我们就可以将已经注入容器的DataSource交由ReadWriteSplitRoutingDataSource这个动态路由管理，最后将这个动态路由添加到SqlSessionFactory中

```bash
//跟xml配置一样，将datasource添加到sqlsessionfactory中,通过MybatisAutoConfiguration自动将sqlsessionFactory注入到Spring容器中
@Configuration
//意思是在DataSourceConfiguration解析注入完成后再配置MybatisConfiguration，因为没有datasource无法生成sqlsessionfactory,存在先后顺序
@AutoConfigureAfter({DataSourceConfiguration.class})
public class MybatisConfiguration extends MybatisAutoConfiguration{
	
	@Resource(name="masterDataSource")
	private DataSource masterDataSource;
	
	@Resource(name="slaveDataSource")
	private DataSource slaveDataSource;
	
	@Bean(name="sqlSessionFactory")
	public SqlSessionFactory sqlSessionFactory() throws Exception {
		return super.sqlSessionFactory(roundRobinRountingDataSource());
	}
	
	public AbstractRoutingDataSource roundRobinRountingDataSource() {
		ReadWriteSplitRoutingDataSource proxy = new ReadWriteSplitRoutingDataSource();
                //也可以使用普通的HashMap
		SoftHashMap targetDataSource = new SoftHashMap();
		targetDataSource.put(DataBaseContextHolder.DataBaseType.MASTER, masterDataSource);
		targetDataSource.put(DataBaseContextHolder.DataBaseType.SLAVE, slaveDataSource);
		proxy.setDefaultTargetDataSource(masterDataSource);
		proxy.setTargetDataSources(targetDataSource);
		return proxy;
	}
}
```

## 自定义annotation

那么切换的模式已经搭建好了，入口如何设置呢？我们也不可能说手动在代码中写死，最便捷的做法就是把配置的数据源类型都设置成为注解标签，在service层中需要切换数据源的方法上标注注解标签，调用相应方法切换数据源

```bash
/**
 * 该注解ReadOnlyConnection，注释在service方法上，标注为链接slaves库
 */
@Target({ElementType.METHOD,ElementType.TYPE}) //该注解作用在方法上
@Retention(RetentionPolicy.RUNTIME)  //方法运行时起作用
public @interface ReadOnlyConnection {

}
```

通过一个拦截器具体实现ReadOnlyConnection注解的功能

```bash
@Aspect
@Component
public class ReadOnlyConnectionInterceptor implements Ordered{

	public static final Logger logger = LoggerFactory.getLogger(ReadOnlyConnectionInterceptor.class);

	@Around("@annotation(readOnlyConnection)") //织入点语法，在标注的方法之前之后执行相应操作
	public Object proceed(ProceedingJoinPoint proceedingJoinPoint, ReadOnlyConnection readOnlyConnection) throws Throwable {
		try {
			logger.info("set database connection to read only");
			//当某方法引用了ReadOnlyConnection这个注解时，方法执行之前将DataBaseType由MASTER-->SLAVE
			DataBaseContextHolder.setDataBaseType(DataBaseContextHolder.DataBaseType.SLAVE);
			//引用注解的原方法继续执行完毕
			Object result = proceedingJoinPoint.proceed();
		    return result;
		}finally {
			//保证下次进程默认还是master数据源
			DataBaseContextHolder.clearDataBaseType();
			logger.info("restore database connection");
		}
	}
	
	@Override
	public int getOrder() {
		return 0;
	}
}
```

ok！至此整个数据源动态切换的流程已基本实现，当我们进行读写操作时需要MasterDataSource，无需修改使用默认的即可；但是进行只读操作时，需要SlaveDataSource就要在相应的Service方法上添加@ReadOnlyConnection注解

## 总结

其实整个方案的核心就是通过添加一个注解标签，来动态的setDataBaseType的值，然后数据源代理类根据getDataBaseType的值作为key获取到保存了所有DataSource的Map的Value，容器根据value生成SqlSessionFactory操作数据源

# 事务控制

单数据源做事务控制是很容易的，以传统配置为例

```bash
	WebApplicationContext wac = ContextLoader.getCurrentWebApplicationContext();
	DataSourceTransactionManager txManager = (DataSourceTransactionManager) wac.getBean("oracleTransactionManager");
	DefaultTransactionDefinition def = new DefaultTransactionDefinition();
	def.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
	TransactionStatus tStatus = txManager.getTransaction(def);
	try {
		insert();
		update();
		delete();
		...
		txManager.commit(tStatus);
	} catch (Exception e) {
		e.printStackTrace();
		txManager.rollback(tStatus);
	}
```

但是涉及到多数据源的切换使用时，需要避免使用同一事务，因为很难保证事务的一致性，解决此类问题我们只能保证最终的一致性，可以使用version版本号或其他手段实现