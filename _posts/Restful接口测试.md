---
title: Restful接口测试
date: 2017-04-02 19:43:01
tags:
- Restful
categories: 
- Tool
---

记录

<!--more-->

## postmen工具

略

## Java原生API实现

```java
public class Test {

    /**
     * POST请求restful接口
     */
    public static void restfulApiCheck(String urlPath, String jsonParams) throws Exception {
        //URL对象
        URL url = new URL(urlPath);
        //打开连接
        HttpURLConnection conn = (HttpURLConnection)url.openConnection();
        //设置提交类型
        conn.setRequestMethod("POST");
        //当前连接可从服务器读取数据 默认true
        conn.setDoInput(true);
        //允许写出数据 默认false
        conn.setDoOutput(true);
        //获取从服务器写出数据的流
        OutputStream os = conn.getOutputStream();
        os.write(jsonParams.getBytes());
        os.flush();
        //获取服务器端响应数据
        BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream(), "utf-8");
        String result = null;
        while(br.read() != -1) {
            result = br.readLine();
            System.out.println("result:" + result);
        }
    }

    public static void main(String args[]) {
        String urlPath = "http://serverip:port/...";
        String jsonParams = "json={'':'','':'','':''}";
        restfulApiCheck(urlPath, jsonParams);
    } 
}
```

## 