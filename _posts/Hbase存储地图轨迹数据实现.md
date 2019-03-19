---
title: Hbase存储地图轨迹数据实现
date: 2017-08-11 19:43:01
tags:
- API
- Hbase
- Hadoop
- Zookeeper
categories: 
- Hadoop栈
---

记录Hadoop+Hbase+Zookeeper环境下存储与查询地图轨迹数据的实现代码

<!--more-->

## 常量类

```java
/**
 * @author lf
 */
public class Constant {
    /**
     * Hbase连接相关配置常量
     */
    public interface HbaseConfigInfo {
        public static final String ZK_CLIENT_PORT = "hbase.zookeeper.property.clientPort";
        public static final String ZK_QUORUM = "hbase.zookeeper.quorum";
        public static final String ZK_ZNODE_PARENT = "zookeeper.znode.parent";
        public static final String HBASE_MASTER = "hbase.master";

        public static final String HBASE_TABLE_NAME = "hbase.table.name";
        public static final String HBASE_TABLE_FAMILY = "hbase.table.family";
    }
}
```

## 配置文件

track.Properties

```java
###hbase address###
hbase.zookeeper.property.clientPort=2181
hbase.zookeeper.quorum=158.222.177.104,158.222.177.101,158.222.177.110
hbase.master=158.222.177.103:60010,158.222.177.107:60010,158.222.177.112:60010
zookeeper.znode.parent=/hyperhbase1

###table info###
hbase.table.name=bgis_track
hbase.table.family=track_info
```

applicationContext.xml

```xml
<beans>
    <bean id="propertyConfigurer"
        class="com.zjjzfy.bgis.track.config.PropertyPlaceholderConfigurer">
        <property name="locations">
            <list>
                <value>classpath:track.properties</value>
            </list>
        </property>
    </bean>
</beans>
```

## 配置类

```java
/**
 * @author lf
 */
public class Property {
    private static java.util.Properties property;

    private Property() {   
    }

    static void init(java.util.Properties props) {
        property = props;
    }

    public static String getProperty(String key) {
        return property.getProperty(key);
    }

    public String getProperty(String key, String defaultValue) {
        return property.getProperty(key, defaultVlaue);
    }
}


/**
 * @author lf
 */
public class PropertyPlaceholderConfigurer extends 
    org.springframework.beans.factory.config.PropertyPlaceholderConfigurer {
    private static Properties props;

    public Properties mergeProperties() throws IOException {
        props = super.mergeProperties();
        Property.init(props);
        return props;
    }

    public static String getProperty(String key) {
        return props.getProperty(key);
    }

    public String getProperty(String key, String defaultValue) {
        return props.getProperty(key, defaultValue);
    }
}
```



## 服务器连接工厂类

```java
/**
 * @author lf
 */
public class HbaseFactory {

    private static Configuration configuration = null;
    private static HConnection connection = null;
    private static HBaseAdmin admin = null;

    private static String zookeeperClientPort = Property.getProperty(HbaseConfigInfo.ZK_CLIENT_PORT);
    private static String zookeeperQuorum = Property.getProperty(HbaseConfigInfo.ZK_QUORUM);
    private static String hbaseMaster = Property.getProperty(HbaseConfigInfo.HBASE_MASTER);
    private static String zookeeperZnodeParent = Property.getProperty(HbaseConfigInfo.ZK_ZNODE_PARENT);

    /**
     * get Configuration
     * @return Configuration
     */
    private static Configuration getConfiguration() {
        if(configuration == null) {
            synchronized (this) {
                if(configuration == null) {
                    configuration = HbaseConfiguration.create();
                    configuration.set(HbaseConfigInfo.ZK_CLIENT_PORT, zookeeperClientPort);
                    configuration.set(HbaseConfigInfo.ZK_QUORUM, zookeeperQuorum);
                    configuration.set(HbaseConfigInfo.HBASE_MASTER, hbaseMaster);
                    configuration.set(HbaseConfigInfo.ZK_ZNODE_PARENT, zookeeperZnodeParent);
                }
            }
        }
        return configuration;
    }

    /**
     * get Connection
     * @return HConnection
     */
    public static HConnection getConnection() throws Exception {
        if(connection == null || connection.isClosed()) {
            synchronized(this) {
                if(connection == null || connection.isClosed()) {
                    configuration = getConfiguration();
                    connection = HConnectionManager.createConnection(configuration);
                    return connection;
                }
            }
        }
    }

    /**
     * get HbaseAdmin
     * @return HbaseAdmin
     */
    public static HbaseAdmin getHbaseAdmin() throws Exception {
        if(admin == null) {
            synchronized(this) {
                if(admin == null) {
                    configuration = getConfiguration();
                    admin = new HBaseAdmin(configuration);
                    return admin;
                }
            }
        }
    }

    /**
     * close HConnection and HbaseAdmin 
     */
    public static synchronized void closeConnAndAdmin() throws Exception {
        if(admin != null) {
            admin.close();
        }
        if(connection != null) {
            connection.close();
        }
    }
}
```

## 数据操作API封装类

```java
/**
 * @author lf
 */
public class HbaseTemplate {

    /**
     * 创建表
     * @param tableName
     * @param family
     * @return boolean
     * @throws Exception
     */
    public static boolean createTable(String tableName, String family) throws Exception {
        HBaseAdmin admin = HbaseFactory.getHbaseAdmin();
        if(admin.tableExists(tableName)) {
            return false;
        }
        HTableDescriptor tableDescriptor = new HTableDescriptor(TableName.valueOf(tableName));
        //若创建多个family
        //for(String family : familys) {
        //    tableDescriptor.addFamily(new HColumnDescriptor(family));
        //}
        tableDescriptor.addFamily(new HColumnDescriptor(family));
        admin.createTable(tableDescriptor);
        return true;
    }

    /**
     * 删除表
     * @param tableName
     * @return boolean
     * @throws Exception
     */
    public static boolean dropTable(String tableName) throws Exception {
        HBaseAdmin admin = HbaseFactory.getHbaseAdmin();
        if(!admin.tableExists(tableName)) {
            return false;
        }
        TableName table = TableName.valueOf(tableName);
        admin.disableTable(table);
        admin.deleteTable(table);
        return true;
    }

    /**
     * 添加单条数据
     * @param tableName
     * @param put
     * @return boolean
     * @throws Exception
     */
    public static boolean putData(String tableName, Put put) throws Exception {
        //验证表是否存在会影响效率
        //HBaseAdmin admin = HbaseFactory.getHbaseAdmin();
        //if(!admin.tableExists(tableName)) {
        //    return false;
        //}
        TableName table = TableName.valueOf(tableName);
        HTableInterface hTable = HbaseFactory.getConnection().getTable(table);
        hTable.put(put);
        hTable.close();
        return true;
    }

    /**
     * 获取单个rowkey对应的数据
     * @param tableName
     * @param rowkey
     * @param family
     * @return Map<String, String>
     * @throws Exception
     */
    public static Map<String, String> getCellAndValueByRowkey(String tableName, String family, String rowkey) throws Exception {
        Map<String, String> result = null;
        HTableInterface hTableInterface = HbaseFactory.getConnection().getTable(TableName.valueOf(tableName));
        Get get = new Get(Bytes.toBytes(rowkey));
        get.addFamily(Bytes.toBytes(family));
        Result r = hTableInterface.get(get);
        List<Cell> cs = r.listCells();
        if(cs == null || cs.size() <= 0) {
            return result;
        }
        result = new HashMap<String, String>();
        for(Cell cell : cs) {
            String qualifier = Bytes.toString(CellUtil.cloneQualifier(cell));
            String value = BYtes.toString(CellUtil.cloneValue(cell));
            result.put(qualifier, value);
        }
        return result;
    }

    /**
     * 获取一个rowkey范围内的所有数据
     * @param tableName
     * @param startRowkey
     * @param endRowkey
     * @return List<Map<String, String>>
     * @throws Exception
     */
    public static List<Map<String, String>> getCellAndValueByRange(String tableName, String startRowkey, String endRowkey) throws Exception {
        List<Map<String, String>> rowkeyList = null;
        TableName table = TableName.valueOf(tableName);
        HTableInterface hTableInterface = HbaseFactory.getConnection().getTable(table);
        Scan scan = new Scan();
        scan.setStartRow(Bytes.toBytes(startRowkey));
        scan.setStopRow(Bytes.toBytes(endRowkey));
        ResultScanner scanner = hTableInterface.getScanner(scan);
        rowkeyList = scanner == null ? rowkeyList : new ArrayList<Map<String, String>>();
        for(Result r : scanner) {
            if(r.isEmpty()) continue;
            String rowkey = new String(r.getRow());
            List<Cell> cs = r.listCells();
            if(cs == null || cs.size() <= 0) continue;
            Map<String, String> columnMap = new HashMap<String, String>();
            columnMap.put("rowkey", rowkey);
            for(Cell cell : cs) {
                String qualifier = Bytes.toString(CellUtil.cloneQuallifier(cell));
                String value = Bytes.toString(CellUtil.cloneValue(cell));
                cloumnMap.put(qualifier, value);
            }
            rowkeyList.add(cloumnMap);
        }
        hTableInterface.close();
        return rowkeyList;
    } 
}
```

## 反射组装Put

```java
/**
 * 组装Put
 * @param rowkey
 * @param track
 * @return Put
 * @throws Exception
 */
private Put installPut(String rowkey, Track track) throws Exception {
    Put put = new Put(Bytes.toBytes(rowkey));
    byte[] family = Bytes.toBytes(Property.getProperty(HbaseConfigInfo.HBASE_TABLE_FAMILY));
    Field[] fields = Track.class.getDeclaredFields();
    for(Field field : fields) {
        String fieldName = field.getName();
        String startIndex = fieldName.subString(0,1).toUpperCase();
        String methodName = "get" + startIndex + fieldName.subString(1);
        Method method = Track.class.getDeclaredMethod(methodName);
        String fieldValue = (String)method.invoke(track, null);
        if(fieldValue == null || "".equals(fieldValue)) continue;
        put.add(family, Bytes.toBytes(fieldName), Bytes.toBytes(fieldValue));
    }
    return put;
}
```











