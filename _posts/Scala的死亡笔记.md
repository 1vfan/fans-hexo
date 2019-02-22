---
title: Scala的死亡笔记
date: 2017-08-19 21:43:01
tags:
- Scala
categories: 
- Scala
---

记录Scala的基础语法、使用说明

<!--more-->

# 特性

> Scala可与Java混编

Scala runs on the JVM, so Java and Scala stacks can be freely mixed for totally seamless integration.

Scala也运行在JVM上，所以Java和Scala栈可以自由混合达到完全无缝集成。

> 自动推测类型

So the type system doesn’t feel so static. Don’t work for the type system. Let the type system work for you!

所以这个类型系统并不是那么静态的。 不要为类型系统工作。 让类型系统为你工作！

> 并发和分布式（Actor）

Use data-parallel operations on collections, use actors for concurrency and distribution, or futures for asynchronous programming.

在集合上使用数据并行操作，在并发和分发中使用参与者，在异步编程中使用未来。

> 特征(类似java中interfaces 和 abstract结合)

Combine the flexibility of Java-style interfaces with the power of classes. Think principled multiple-inheritance.

将Java风格界面的灵活性与类的强大功能相结合。 认为有原则的多重继承。

> 模式匹配（类似java switch）

Think “switch” on steroids. Match against class hierarchies, sequences, and more.

匹配类层次结构，序列等。

> 高阶函数

Functions are first-class objects. Compose them with guaranteed type safety. Use them anywhere, pass them to anything.

函数是一流的对象。 以保证的类型安全性来组成它们。 在任何地方使用它们，将它们传递。

# 环境配置

## 系统环境

点击 [<font face="Times New Roman" color=#0099ff size=3>2.10.4</font>](http://www.scala-lang.org/download/2.10.4.html) 下载解压，配置环境变量，并验证

```bash
C:\Users\lf>scala -version
Scala code runner version 2.10.4 -- Copyright 2002-2013, LAMP/EPFL
```

## 开发环境

选择安装插件后的IDEA作为Scala的开发工具无疑是最好用的，当然也可以使用安装插件的Eclipse或Scala IDE，介绍下IDEA安装Scala插件并创建项目

Setting -> Plugins -> search 'Scala' -> install -> restart IDEA -> create new project -> scala -> 选择jdk和scala的sdk -> 添加sdk -> create -> Browse -> system ->finish 

# 语法基础

## 数据类型

![type](/img/Scala/scala_type.png)

```
Byte          8  bit
Short、Char   16 bit
Int、Float    32 bit
Long、Double  64 bit
Boolean、String
Unit    : 无返回值函数的类型，等同于void
Null    : 空值或空引用（AnyRef的子类）
AnyVal  ：所有值类型的超类
AnyRef  : 所有引用类型的超类 
Any     : 所有类型的超类（任何实例都属于Any）
Nothing : 所有类型的子类型（表示没有值）
Nil     : 长度为0的List
None    : 和Some作为Option的两个子类，用于安全函数得得返回值        
```

## 类与对象

Scala中object是单例对象（相当于java中的工具类，可看成是定义静态方法的类），在object修饰的代码块中定义的常量、变量、方法都是静态的，使用object时不用new，不可以传参数；class类的属性自带getter、setter方法；使用class时需要new（new的时候class中除了方法不执行，其他都执行）.

```java
//创建类
class Person {
    //var声明可变变量 (var name:String = "stefan")
    var name = "Stefan"
    name = "Scala"
    //val声明不可变常量
    val age = 25

    //使用def声明方法，Unit表示该方法无返回值
    def sayHello(): Unit = {
        println(this.name + " : " + this.age)
    }
}

//创建对象
object Test_01 {
    def main(args: Array[String]): Unit = {
        val person = new Person()
        person.sayHello()
    }
}
```

同一文件Test_02.scala中，object对象和class类的名称相同，则该对象就是这个类的伴生对象，这个类就是该对象的伴生类；可以互相访问私有变量.

```java
//伴生类
class Test_02 {

}

//伴生对象
object Test_02 {
    def main(args: Array[String]) {
        var name = "setfan"
        name = "scala"
        val age:Int = 14
        println("name: " + name + "\n" + "age: "+ age)
    }
}
```

## 构造函数

Scala的class类默认可以传参数，默认的传参数就是默认的主构造函数；可以在类中创建任意数量的辅助构造函数（即重写构造时需要在辅助构造函数内部使用this调用主构造函数放在第一行）.

```java 
class Test_03 {

}

object Test_03 {
    def main(args: Array[String]): Unit = {
        val p1 = new Person("stefan", 25)
        p1.sayHello()
        println("-----------------------------------------------")
        val p2 = new Person("Scala", 10, "lang")
        p2.sayHello()
    }
}

class Person(param1:String, param2:Int) {
    var name = param1
    var age = param2
    def sayHello(): Unit = {
        println("<1>: " + name + " : " + age)
    }
    var job = ""
    def this(param1:String, param2:Int, param3:String) {
        //this调用主构造函数且要在第一行
        this(param1, param2)
        this.job = param3
        println("<2>: "+ name + " : "+ age + " : " + job + "")
        println("---Person(param1,param2,param3)---")
    }
    println("<3>: " + name + " : "+ age)
    println("---Person(param1,param2)---")
}
```

```
打印结果：
<3>: stefan : 25
---Person(param1,param2)---
<1>: stefan : 25
-----------------------------------------------
<3>: Scala : 10
---Person(param1,param2)---
<2>: Scala : 10 : lang
---Person(param1,param2,param3)---
<1>: Scala : 10
```

## 控制语句

for、to、until

```java
println(1 to 10)
println(1.to(10))
结果都是：Range(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)

println(1.to(10, 3))
步长为3：Range(1, 4, 7, 10)

println(1 until 10)
println(1.until(10))
不包括10：Range(1, 2, 3, 4, 5, 6, 7, 8, 9)

println(1.until(10, 3))
步长为3：Range(1, 4, 7)
```

双重for循环用；隔开

```java
for (i <- 1 to 9; j <- 1 to i) {
    print(i + "*" + j + "=" + i * j + "\t")
    if (i == j) {
        println()
    }
}
```

yield返回一个集合，for循环中可以加入if判断

```java
//一行代码搞定：遍历1-10中偶数放入list集合中
val list = for(i <- 1 to 10; if (i % 2) == 0) yield i
for(elem <- list) {
    println(elem)
}
```

while先判断再执行（不符合不执行）、do while先执行再判断（至少执行一次）

```java
var index = 1

while(index < 0){
    println("--while方法体--")
    //scala中没有index++
    index += 1
}

println("-------------")

do{
    println("--do while方法体--")
}while(index < 0)
```

# 函数

def定义函数；函数传入参数需要定义参数类型；方法返回值一般可不写，可以自动推断（但递归函数和函数返回值为函数类型时必须加上返回类型）；若去掉方法体前的等号，此方法返回类型必定是Unit的（scala可把任意类型转换为Unit，举例：方法体中逻辑最后返回String，该返回值会被转换成Unit，并且值会被丢弃）.

## 简化版

方法返回值类型一般可通过自动推断有时可不写；函数有返回值时return可不写，会把函数中最后一行当做结果返回；若返回值可以一行搞定，可以将{}省略不写.

```java
def fun_00(a:Int, b:Int): Int = {
    return a+b
}
println(fun_00(10,20))

  ||
 \  /
  \/

def fun_01(a:Int, b:Int) = a+b
println(fun_01(10, 20))
```

## 包含默认值参数

可以使用默认值，也可覆盖默认值（传入参数个数与函数定义相同，则传入的数值会覆盖默认值；传入的参数个数小于定义的函数的参数，则需要指定参数名称）

```java
def fun_02(a:Int =10, b:Int) = a+b
println(fun_02(1,2))
println(fun_02(b=2))
println(fun_02(a=1, b=2))
```

## 参数个数可变

添加 * 定义，多个参数使用逗号分隔

```java
//可变参数类型相同 如：Int* Double* 等
def fun_03(elems:Int*) = {
    var sum = 0;
    for(elem <- elems) {
        sum += elem
    }
    sum
}
println(fun_03(1,2,3,4,5,6,7,8,9,10))

//可变参数的类型不同，使用Any*
def fun_03(elems: Any*) = {
    for(elem <- elems) {
        println(elem)
    }
}
fun_03("stefan", 2, 23.00, "A")
```

## 匿名函数

可以将匿名函数返回给一个变量；同时注意匿名函数不能显式的定义返回值类型

```java
//无参匿名函数
val value1 = () => {
    println("my name is Stefan")
}
value1()

//有参匿名函数
val value2 = (a:Int) => {
    println(a)
}
value2(100)

//有返回值匿名函数
val value3 = (a:Int, b:Int) => a+b
println(value3(10, 20))
```

## 递归函数

必须加上返回类型

```java
def fun_04(num:Int): Int = {
    if(num == 1) {
        num
    }else {
        num * fun_04(num-1)
    }
}
println(fun_04(5))
```

## 嵌套函数

```java
def fun_02(num:Int): Int = {
    def fun_01(a: Int, b: Int): Int = {
        if (a == 1) {
            b
        } else {
            fun_01(a-1, a*b)
        }
    }
    fun_01(num, 1)
}
println(fun_02(5))
```

## 偏应用函数

```java
def log(date:Date, logInfo:String): Unit = {
    println(date + ":" + logInfo)
}

log(new Date(), "log1")
log(new Date(), "log2")
log(new Date(), "log3")

  ||
 \  /
  \/

def log(date:Date, logInfo:String): Unit = {
    println(date + ":" + logInfo)
}
//使用 _ 类似占位符
val logQuery = log(new Date(), _:String)

logQuery("log4")
logQuery("log5")
logQuery("log6")
```

## 高阶函数

就是指：该函数的参数是函数 或 该函数的返回类型是函数 或 该函数的参数和返回类型都是函数 的函数.

## 高阶之函数式参数

函数的参数是函数的是高阶函数

```java
//完整版
def fun_01(fun_02: (Int, Int) => Int, c: Int): Int = {
    println(fun_02(10, 20) + c)
}
def fun_03(a: Int, b: Int): Int = {
    a+b
}
fun_01(fun_03, 30)

//精简版
def fun_01(fun_02: (Int, Int) => Int, c: Int) = println(fun_02(10, 20) + c)
def fun_03(a:Int, b:Int) = a+b
fun_01(fun_03, 30)

//匿名版：无需另外定义函数
def fun_01(fun_02: (Int, Int) => Int, c: Int) = println(fun_02(10, 20) + c)
fun_01(((a: Int, b: Int) => {a+b}), 30)


//占位：适用于函数的参数在方法体中只使用了一次
def fun_01(fun_02: (Int, Int) => Int, c: Int) = println(fun_02(10, 20) + c)
fun_01((_+_), 30)
```

### 高阶之函数式返回类型

函数的返回类型是函数的是高阶函数

```java
//完整版
def fun_01(a: Int): (Int, Int) => Int = {
    def fun_02(b: Int, c: Int): Int = {
        a+b+c
    }
    fun_02
}
println(fun_01(1)(2,3))

//返回类型为匿名函数
def fun_01(a: Int): (Int, Int) => Int = {
    (b: Int, c: Int) => {a+b+c}
}
println(fun_01(1)(2,3))

//精简版
def fun_01(a: Int): (Int, Int) => Int = (b, c) => a+b+c
println(fun_01(1)(2,3))  
```

### 高阶之函数式参数+函数式返回类型

```java
//参数是函数、返回类型也是函数
def fun_01(fun_02: (Int, Int) => Int): (Int, Int) => Int = {
    fun_02
}
println(fun_01((a:Int, b: Int) => a+b)(10,20))
```

## 柯里化函数

柯里化函数其实就是高阶函数的简化版

```java
def fun_01(a: Int)(b: Int): Int = {
    a+b
}
println(fun_01(10)(20))

def fun_02(a: Int, b: Int)(c: Int, d: Int): Int = {
    a+b+c+d
}
println(fun_02(1,2)(3,4))
```

# 字符串

略

# 数据结构

## Array

```java
//创建
val arrString1 = new Array[String](4)
arrString1(0) = "1"
val arrString2 = Array[String]("1","2","3","4")
val arrString3 = Array("1","2","3","4")

//默认0
val arrInt = new Array[Int](4)

for(index <- 0 until arrInt.length) {
    arrInt(index) = index * index
}
//arrInt.foreach((x:Int) => println(x))
//arrInt.foreach(println(_))
arrInt.foreach(println)


//默认false
val arrBool = new Array[Boolean](4)
arrBool(0) = true
arrBool.foreach((x:Boolean) => println(x))

//二维数组创建
val doubleArr = new Array[Array[Int]](3)
for(i <- 0 until doubleArr.length) {
    doubleArr(i) = new Array[Int](4)
}
//二维数组赋值
for(i <- 0 until doubleArr.length) {
    for(j <- 0 until doubleArr(i).length) {
    doubleArr(i)(j) = i * j
    print(doubleArr(i)(j) + "\t")
    }
    println()
}
//简化二维数组赋值
for(i <- 0 until doubleArr.length ; j <- 0 until doubleArr(i).length) {
    doubleArr(i)(j) = i * j
    print(doubleArr(i)(j) + "\t")
    if(j == doubleArr(i).length-1) {
    println()
    }
}

//数组合并concat(n个数组)
val arr1 = Array(1,2,3)
val arr2 = Array(4,5,6)
val arr3 = Array(7,8,9)
val arrAll = Array.concat(arr1, arr2, arr3)
arrAll.foreach((x: Int) => print(x + "\t"))

println()

//Array.fill(i)(j)创建一个长度为i值为j的数组
val arrFill = Array.fill(4)("哈" + "\t")
arrFill.foreach(print)
```

## List

```java
//创建
val list = List(0,1,2,3,4,5,6,7,8)
//遍历
list.foreach(x => {print(x + "\t")})

//max  min
println(list.max + "\t" + list.min)

//filter过滤元素
val listFilter = list.filter(x => x < 4)
listFilter.foreach(x => {print(x + "\t")})

//count计算符合条件的元素个数
println(list.count(x => x < 4))


val listStr = List("hello stefan","hello jack","hello marry","hello albert")

//map函数中传入的匿名函数的参数类型与操作的集合中元素类型一致
//map函数中传入的匿名函数的返回类型就是新集合的泛型
val listMap:List[Array[String]] = listStr.map((x: String) => {x.split(" ")})
listMap.foreach(x => {x.foreach(println)})

//flatmap:先map再flat扁平化
val listFlatMap: List[String] = listStr.flatMap((x: String) => {x.split(" ")})
listFlatMap.foreach(println)

//先flatmap再List转Set 可以将重复的去除
listFlatMap.toSet.foreach(println)
```

## Set

```java
val set = Set("1","1","2","2")

set.foreach(x => {print(x + "\t")})

for(elems <- set) {
    print(elems + "\t")
}

//max min
println(set.max + "\t" + set.min)


val set1 = Set(1,2,3,4,5,6)
val set2 = Set(3,4,5,6,7,8)

//交集 打印：3 4 5 6
set1.intersect(set2).foreach(x => {print(x + "\t")})
set1.&(set2).foreach(x => {print(x + "\t")})

//差集：set1中有的而set2中没有  打印： 1 2
set1.&~(set2).foreach(x => {print(x + "\t")})
set1.diff(set2).foreach(x => {print(x + "\t")})

//子集 true/false
println(set1.subsetOf(set2))

val set3 = Set(1,2,3,4,5,5,4,3)
//转List
set3.toList.foreach(x => {print(x + "\t")})
//转Array
set3.toArray.foreach(x => {print(x + "\t")})

//mkString: 将元素组合成String，元素间以传入参数隔开
println(set3.mkString(""))
println(set3.mkString("\t"))
```

## Map

```java
//创建map时，相同的key被后面的相同的key顶替掉，只保留一个
val map = Map((1,"hello"),("2","Stefan"),3 -> "你有freeStyle吗?","4" -> 666)

println(map.get(1).get + "\t" +
        map.get("2").get + "\t" +
        map.get(3).get + "\t" +
        map.get("4").get)

//遍历
map.foreach(x => {println("key:" + x._1 + " -> " + "value:" + x._2)})

//遍历keys
map.keys.foreach(x => {println("key:" + x + " -> " + "value:" + map.get(x).get)})

//遍历values
println(map.values.mkString("\t"))

//filter过滤：留下符合条件的记录
//map.filter(x => {x._2.equals("Stefan")}).foreach(println)
map.filter(_._2.equals("Stefan")).foreach(println)

//count计数：符合条件的记录数
println(map.count(_._2.equals("Stefan")))

//exists：判断是否有符合条件的记录
println(map.exists(_._2.equals("Stefan")))

//contains：map中是否包含某个key
println(map.contains(1))
println(map.contains("1"))
println(map.contains(6))

//map合并
val map1 = Map((1,"1a"),(2,"1b"),(3,"1c"),(4,"1d"))
val map2 = Map((1,"2a"),(2,"2b"),(3,"2c"),(4,"2d"))

//map1合并map1加入map2；map2会替换map1中相同key值的value
println(map1.++(map2).values.mkString("\t"))
//map1合并map2加入map1
println(map1.++:(map2).values.mkString("\t"))
```

## 元组

元组与列表一样，但是内部组成可以是不同类型的元素

```java
//val tuple = new Tuple4(666,"Stefan",2.0,true)
//最大到Tuple22
//val tuple = Tuple4(666,"Stefan",2.0,true)

val tuple = (1,"Stefan",666,2.0,true)

//迭代器
val iterator = tuple.productIterator
while(iterator.hasNext) {
    val tupleValue = iterator.next()
    println(tupleValue)
}

//嵌套使用tuple
val tuple1 = ((1,"Stefan",true),(2,"jack",true),(3,"lucy",false),(4,("mac",6.0,false),true))
println(tuple1._1._2)
println(tuple1._4._2._1)

//swap交换
val tuple2 = Tuple2((1,"Stefan"),(2,"jack"))
println(tuple2._1._2)
println(tuple2.swap._1._2)
```

# Trait

Trait相当于Java的接口，不过比Java的接口要强大（可以定义属性和方法的实现，定义方式与类类似，使用trait关键字修饰）；Scala的类可以继承多个Trait，相当于多继承

```java
def main(args: Array[String]): Unit = {
    val superAnimal =  new SuperAnimal
    println(superAnimal.size + "\t" + superAnimal.color)
    superAnimal.eating("dogA")
    superAnimal.catching("catB")
}

class SuperAnimal extends Dog with Cat {
    override val color = "yellow"
    override val size  = "big"

    override def eating(name: String) = {
        println(size + " " + color + " superAnimal " + name + " eat all animals...")
    }

    override def catching(name: String) = {
        println(size + " " + color + " superAnimal " + name + " catch all animals...")
    }
}

//trait中不可以传参数
trait Dog {
    val color = "red"

    def eating(name: String) = {
        println(color + " dog "+ name + " eat meat...")
    }
}

trait Cat {
    val size = "small"
    //只声明不实现
    def catching(name: String): Unit
}
```

# match

提供模式匹配机制（可匹配值也可以匹配类型），匹配到对应的值或类型后就不再继续往下匹配，都匹配不上时，会匹配到 case _（相当于Java中的default）

```java
def main(args: Array[String]): Unit = {
    val tuple = (1,2,3.0,"Stefan")
    val iterator = tuple.productIterator
    while(iterator.hasNext) {
        val tupleValue = iterator.next()
        matchMethod(tupleValue)
    }
}

def matchMethod(x: Any): Unit = {
    x match {
        //值匹配
        case 1 => println("1: " + x)
        case 2 => println("2: " + x)
        //类型匹配
        case i: Int => println("Int: " + x)
        case i: String => println("String: " + x)
        //全都匹配不上
        case _ => println("not match: " + x)
    }
}
```

# case classes样例类

使用case关键字定义的类就是样例类

```java
//默认实现了toString、equals、copy、hashCode等方法
case class Animal(var name: String, age: Int) {

}

object Test_16 {
  def main(args: Array[String]): Unit = {

    //样例类可new可不new
    val a1 = new Animal("Cat", 2)
    val a2 = new Animal("Dog", 3)
    val a3 = Animal("mouse", 4)

    //当构造参数声明为var类型，会自动实现setter和getter方法
    a2.name = "new Dog"
    println(a2.name)

    val list = List(a1,a2,a3)
    list.foreach((x :Animal) => {
      x match {
        case Animal("Cat", 2) => println(x)
        case Animal("Dog", 3) => println(x)
        case _ => println("not match")
      }
    })
  }
}
```

