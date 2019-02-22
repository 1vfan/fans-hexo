---
title: Java的死亡笔记
date: 2017-02-22 19:43:01
tags:
- DeathNote
categories: 
- Java
---
记录Java编程基础与规范

<!--more-->

# 集合

## 重写equals

只要重写equals，就必须重写hashCode；因为String重写了hashCode和equals方法，所以我们可以直接使用String对象作为key来使用；Set存储的是不重复的对象，依据hashCode和equals进行判断，所以Set存储的对象必须重写这两个方法；同样的自定义对象做为Map的key，也必须重写hashCode和equals

* 自反性原则：对于任何非空引用x，x.equals(x) == true

* 对称性原则：对于任何引用x、y，若x.equals(y) == true，那么y.equals(x) == true

```bash
class User {
    private String name;
    //getter、setter略

    public User(String name){
        this.name = name;
    }

    @Override
    public boolean equals(Object obj){
        if(obj instanceof User){
            User u = (User) obj;
            //添加判断，避免在执行equals时报空指针异常
            if(name == null || u.getName() == null){
                return false;
            }else{
                return name.equals(u.getName());
            }
        }
        return false;
    }
}
```

* 传递性原则：对于实例对象x、y、z，若x.equals(y) == true，y.equals(z) == true，则x.equals(z)必须 == true





## 集合排序

```bash
import java.util.Comparator;

public class CommonComparator implements Comparator<Object> {
    /**
     * 根据Demo对象中的distance距离字段将数组中的Demo按升序排列
     **/
    public int compare(Object o1, Object o2){
        double firDistance = ((Demo)o1).getDistance();        
        double secDistance = ((Demo)o2).getDistance();
        double flagDistance = firDistance - secDistance;
        if(flagDistance > 0){
            return 1;
        }else if(flagDistance < 0){
            return -1;
        }else{
            return 0;
        }

        //避免使用如下方式，没有处理相等的情况，在实际应用中会出现异常
        //return firDistance > secDistance ? 1 : -1;
    }
}
```

```bash
import java.util.Collections;

List<Demo> list = new ArrayList<Demo>();
Collections.sort(list, new CommonComparator());
```

## 数组转集合

转List后只能get方法获取值，不能使用List相关的修改方法，如果强行使用add、remove、clear方法会抛UnsupportedOperationException异常

```bash
String[] str = new String[]{"a", "b"};
List list = Arrays.asList(str);
list.get(0);   //a
list.get(1);   //b
list.add("c"); //运行时异常
```

因为asList返回的list只是一个Arrays的内部类，并没有实现List的修改方法，后台数据仍是数组，所以修改原数组数据后list的值也会相应改变

```bash
str[0] = "c";
list.get(0);  //c
```

## 集合转数组

转Array使用toArray(T[] array)，T必须和集合的类型一致，数组大小是list.size() （最好保证入参数组array大小与集合元素个数一致，数组array分配空间不够时，toArray方法内部将重新分配内存空间，并返回新数组地址；数组array分配空间超出时，超出部分数组元素将被置为null）

```bash
List<String> list = new ArrayList<String>(2);
list.add("a");
list.add("b");
String[] array = new String[list.size()];
array = list.toArray(array);
```

直接使用toArray无参方法存在问题，此方法返回值只能是Object[]类，若强转其它类型数组报ClassCastException异常

```bash
String[] array = new String[list.size()];
array = list.toArray();  //ClassCastException异常
```

## 遍历Map

1. 二次取值，可获取key和value，代码简洁；但效率低下

```java
for(String key : map.keySet()) {
    System.out.println(key)
    String value = map.get(key);
}
```

2. 普遍使用，可获取key和value且效率高

```java
for(Map.Entry<String,String> entry : map.entrySet()) {
    String key = entry.getKey();
    String value = entry.getValue();
}
```

3. 效率最高，但无法同时取出key和value

```java
for(String key : map.keySet()) {
    System.out.println(key)
}

for(String value : map.values()) {
    System.out.println(value)
}
```

# 时间

## SimpleDateFormat

```java
Date date = new Date();
long timeStamp = date.getTime();
SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
//String dateTime = format.format(date);
String dateTime = format.format(timeStamp);
SimpleDateFormat parse = new SimpleDateFormat("yyyy-MM-dd");
Date date = parse.parse(dateTime);
```


## Calendar

```java
//201801 -> 2017011
Calendar cal = Calendar.getInstance();
cal.add(Calendar.MONTH, -2);
SimpleDateFormat format = new SimpleDateFormat("yyyy-MM");
String date = format.format(cal.getTime());
```

