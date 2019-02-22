---
title: Netty基础之实现简单通信
date: 2017-06-18 10:34:02
tags:
- Netty
- Socket
categories: 
- Netty
---

记录Netty简单通信实现

<!--more-->

# Why Netty ?

最主要的原因就是简单！Netty作为最流行的NIO框架，具备以下优点

```bash
易用：API简单丰富，从复杂的网络代理代码中解耦业务逻辑
性能：所有NIO框架中综合性能最优
功能：内置多种编解码和主流协议，功能强大
稳定：修复了所有JDK的NIO类库已知的BUG（如不再因过快、过慢或超负载连接导致OutOfMemoryError、不再有在高速网络环境下NIO读写频率不一致等问题）
扩展：由于Netty基于NIO2.0，所以整个Netty都是异步的，使用异步代码来解决扩展性问题
应用：各大互联网应用、分布式系统底层都在使用，如rocketMQ、Elasticsearch、JMS框架、Hadoop的RPC框架、
阿里分布式服务框架Dubbo的RPC框架使用Netty作为基础通信组件的Dubbo协议进行节点间通信，用于实现各进程节点之间的内部通信
```
我们不需要再用复杂的代码逻辑实现通信，不需要考虑编解码问题，性能问题，半包读写问题等，这些Netty都已经帮我们实现好了，使用即可

# 架构图

![png1](/img/20170618_1.png)

底层核心：零拷贝原理、开放的API、可扩展的事件模型

传输服务：支持很多种协议，包括socket、TCP、UDP、HTTP、文件传输等以及直接操作JVM的内置管道

协议支持：WebSocket、服务器推、加密安全协议、压缩格式、大文件传输等等

# 通信实现

## 简单步骤

```bash
创建两个NIO线程组，一个专用于网络事件处理（接收客户端的连接），一个专用于网络通信读写
创建一个ServerBootstrap对象，配置Netty的一系列参数
创建一个实际处理数据的ChannelInitializer，进行初始化的简单工作（如：传出数据的字符集、编码格式、实际处理数据的接口）
绑定端口，执行同步阻塞方法等待服务器端启动
```

## 代码实现

### Client端

```bash
/**
 * Client端配置启动
 * @author lf
 *
 */
public class Client {
	public static void main(String[] args) throws Exception{
		//接收客户端网络读写的线程工作组
		EventLoopGroup work = new NioEventLoopGroup();
		
		//启动NIO服务的辅助启动类
		Bootstrap b = new Bootstrap();
		//链式编码
		b.group(work)//绑定线程工作组
		.channel(NioSocketChannel.class)//设置NIO模式
		//初始化绑定服务通道
		.handler(new ChannelInitializer<SocketChannel>() {
			@Override
			protected void initChannel(SocketChannel sc) throws Exception {
				//为通道进行初始化；数据传输过来会进行拦截和执行
				sc.pipeline().addLast(new ClientHandler());
			}
		});
		
		//连接地址端口
		ChannelFuture cf = b.connect("127.0.0.1", 8765).syncUninterruptibly();
		
		//发送数据
		String request = "Hello,Netty!!";
		cf.channel().writeAndFlush(Unpooled.copiedBuffer(request.getBytes()));
		
		//释放连接
		cf.channel().closeFuture().sync();
		work.shutdownGracefully();
	}
}


/**
 * ClientHandler
 * @author lf
 *
 */
public class ClientHandler extends ChannelInboundHandlerAdapter{

}
```

### Server端

```bash
/**
 * Server端配置启动
 * @author lf
 *
 */
public class Server {
	public static void main(String[] args) throws Exception{
		//接收客户端连接的线程工作组
		EventLoopGroup boss = new NioEventLoopGroup();
		//接收客户端网络读写的线程工作组
		EventLoopGroup work = new NioEventLoopGroup();
		
		//启动NIO服务的辅助启动类
		ServerBootstrap b = new ServerBootstrap();
		//链式编码
		b.group(boss, work)//绑定两个线程工作组
		.channel(NioServerSocketChannel.class)//设置NIO模式
		.option(ChannelOption.SO_BACKLOG, 128)//设置TCP缓冲区
		.option(ChannelOption.SO_RCVBUF, 32*1024)//设置接收数据缓冲区大小
		.childOption(ChannelOption.SO_SNDBUF, 32*1024)//设置发送数据缓冲区大小
		.childOption(ChannelOption.SO_KEEPALIVE, Boolean.TRUE)//设置保持连接
		/**
		option()和childOption()
		option()是提供给NioServerSocketChannel用来接收进来的连接,也就是boss线程
		childOption()是提供给由父管道ServerChannel接收到的连接，也就是worker线程,在这个例子中也是NioServerSocketChannel
		**/
		
		//初始化绑定服务通道
		.childHandler(new ChannelInitializer<SocketChannel>() {
			@Override
			protected void initChannel(SocketChannel sc) throws Exception {
				//为通道进行初始化；数据传输过来会进行拦截和执行（相当于业务逻辑）
				sc.pipeline().addLast(new ServerHandler());
			}
		});
		
		//绑定端口；执行同步阻塞方法等待服务端启动
		ChannelFuture cf = b.bind(8765).sync();
		
		//释放连接
		cf.channel().closeFuture().sync();
		work.shutdownGracefully();
		boss.shutdownGracefully();
	}
}
```

```bash
/**
 * ServerHandler
 * @author lf
 *
 */
public class ServerHandler extends ChannelInboundHandlerAdapter{
	
	/**
	 * 监听通道激活的时候 触发的方法
	 */
	@Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
		System.out.println("-------------->通道激活<-------------");
    }
	
	/**
	 * 监听通道里有数据进行读取的时候 触发的方法
	 */
	@Override
    public void channelRead(ChannelHandlerContext ctx /*netty服务的上下文*/, Object msg /*网络传输的数据*/) throws Exception {
		/**
		 * NIO通信传输的数据是本质是buffer对象
		 * 但是为什么这里是Object呢？ --> 因为buffer对象操作比较麻烦，以后我们可以根据不同的序列化框架将Object数据转成自定义的对象
		 */
		//所以我们这里的msg其实就是buffer，所以可以强转
		ByteBuf buf = (ByteBuf)msg;
		byte[] request = new byte[buf.readableBytes()];
		buf.readBytes(request);
		String message = new String(request, "UTF-8");
		System.out.println("----------->服务端接收到数据：" + message);
		
		/**
		 * 正常往外写返回数据一般不会再去创建一个类继承ChannelOutboundHandlerAdapter，太麻烦了
		 * 会使用ChannelHandlerContext上下文往外写冲刷，而且是异步的
		 * 这里需要Object，其实还是Buffer对象，可以通过netty自带的工具类将字节数组直接转成需要的Buffer
		 */
		String response = "我是返回的数据";
		ctx.writeAndFlush(Unpooled.copiedBuffer(response.getBytes()));
    }
	
	/**
	 * 监听通道的数据读取完成 触发的方法
	 */
	@Override
    public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
		System.out.println("-------------->数据读取完毕<-------------");
    }
	
	/**
	 * 监听网络通信出现异常 触发的方法
	 */
	@Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
		ctx.close();
		System.out.println("-------------->数据读取异常<-------------");
    }
}
```

Server端控制台打印

```bash
-------------->通道激活<-------------
----------->服务端接收到数据：Hello,Netty!!
-------------->数据读取完毕<-------------
```