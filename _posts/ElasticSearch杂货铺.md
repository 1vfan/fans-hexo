---
title: ElasticSearch杂货铺
date: 2017-02-27 19:43:01
tags:
- ElasticSearch
categories: 
- ELK
---

记录ElasticSearch的基础知识

<!--more-->


# 应用场景

Elasticsearch是一个开源的分布式的restful搜索和分析引擎，在以下三个互联网领域中应用尤为突出：

* 搜索领域，相较于solr，天生的分布式会更加有优势
* Json文档数据库，相较于MongoDB，读写性能更佳，且支持更丰富的地理位置查询以及数字、文本的混合查询等
* 时序数据分析处理，目前主要是日志处理、监控数据的存储、分析和可视化方面

# 版本迁移

将应用程序从一个Elasticsearch版本迁移到另一个版本时需要注意的基本规则:

* 次要版本之间迁移: 如5.x对5.y 可以进行一次升级一个节点
* 连续的主要版本之间迁移: 如2.x对5.x 需要一个完整的集群重启
* 非连续的主要版本之间迁移: 如1.x -> 5.x 不支持


# 专业词汇

* 节点 Node

物理概念，一个节点就是一个属于某集群的ElasticSearch的运行实例，一般是一台机器上的一个进程；（测试时可以在单个服务器上启动多个节点，但通常每个服务器应该有一个节点）启动时，节点将使用单播来发现具有相集群名称的现有集群，并尝试加入该集群。

* 集群 Cluster

集群由共享相同集群名称的一个或多个节点组成，每个集群都有一个由集群自动选择的主节点（若当前的主节点发生故障，可将其替换）.

* 索引 Index

逻辑概念，索引（类似关系数据库中的表）就是倒排索引文件，``倒排索引``是实现单词到文档映射关系的最佳实现方式和最有效的索引结构，一个索引的数据文件（包括映射信息Mapping和倒排数据文件）可能会分布于一台机器，也有可能分布于多台机器.

* 映射 Mapping

映射（类似关系数据库中的表结构schema）每个索引都有一个映射，负责定义索引应该具有的主分片和副本分片的数量以及索引内每种字段的类型，及设置一些索引范围；映射既可以明确定义，也可以在插入文档时自动生成.

* 分片 Shard

分片是一个单独的Lucene实例，为了支持更大量的数据，索引一般会按某个维度分成多个分片，一个节点(Node)一般会管理多个分片，这些分片可能属于同一索引，也有可能属于不同索引；为保证可靠性和可用性，同一个索引的分片会分布在不同节点上；节点故障或新增节点时，分片会自动从一个节点移到另一节点.

* 主分片 Primary Shard

每个文档都存储在一个主分片中。索引文档时，首先在主分片上索引，然后在主分片的所有副本上索引（默认索引有5个主分片）您可以指定更少或更多的主分片来缩放索引可以处理的文档数量 。创建索引后，您无法更改索引中的主要碎片数量.

* 副本分片 Replica Shard

备份数据，每个主分片可以有0个或多个副本分片（默认每个主分片会有1个副本，数量可以在现有基础上动态更改），副本分片永远不会与其主分片在同一节点上启动，副本数据保证强一致或最终一致.

建立索引的时候，一个文档通过路由规则定位到主分片，并将其发送到该主分片上建立索引，成功后再将该文档发送到对应的副本分片上建立索引，成功后最后才返回成功，索引数据就全部位于主分片和副本分片中. 

在这种基于本地文件系统存储的分布式系统架构中，当出现网络中断或机器宕机等状况，造成某个副本分片或主分片丢失时，就需要将丢失的分片数据在其他节点上恢复回来，从其他副本分片中取出丢失的所有数据全量拷贝到新节点上构造新分片，整个拷贝过程需要一段时间.

综上，副本分片具有以下优点:

服务可用性: 主节点故障后，副本分片可以升级为主分片，服务很快恢复使用.
数据可靠性: 用副本分片做备份，避免因为故障导致数据丢失而重新建立索引.
提升查询能力: 当GET和搜索请求量很大，主分片无法承受所有流量时，通过增加副本分片可以分流查询的压力，提高系统的并发度，扩展查询能力.

* 文档 Document

文档是存储在ES中的JSON文档（类似关系数据库表中的一行），存储在索引的分片中，并配有ID、type、version，索引的原始JSON文档存储在``_source``字段中.

* 类型 Type

文档的类型，搜索API可以按类型过滤文档（但在6.x后被废）；具有相同索引中不同类型的相同名称的字段必须具有相同的映射（它定义文档中的每个字段如何索引并使其可搜索）.

* 标识 ID

使用ID标识文档，在同一index+type中，ID必须是唯一的（默认自动生成）.

* 字段 Field

一个文件包含字段或键-值对的列表。该值可以是简单（标量）值（例如字符串，整数，日期），也可以是像数组或对象这样的嵌套结构。
字段与关系数据库中的表中的列相似。所述映射用于每个字段具有一个字段类型（不要与文件相混淆类型），
其指示可以被存储在该字段中的数据的类型，例如integer，string，object。映射还允许您定义（除其他外）如何分析字段的值。

* 源字段 source field

默认情况下，您索引的JSON文档将存储在 _source字段中，并将由所有获取和搜索请求返回。这允许您直接从搜索结果中访问原始对象，而不需要第二步从ID中检索对象。

* 路由 Routing

索引文档时，它将存储在单个主分片上。该碎片是通过散列routing值来选择的。
默认情况下，routing值是从文档的ID派生的，或者如果文档具有指定的父文档，则从父文档的ID派生（以确保子文档和父文档存储在同一个分片上）。
此值可以通过指定被覆盖routing在索引时间值，或者一个路由选择字段中的映射。

* 词语 term

ES中索引的确切值，可以使用术语查询进行搜索（即精确值）.

* 文本 text

文本（或全文）是普通的非结构化文本，如本段落。默认情况下，文本将被分析为 条目，这是实际存储在索引中的内容。
文本字段需要在索引时间进行分析以便作为全文进行搜索，并且必须在搜索时分析全文查询中的关键字以产生（和搜索）在索引时间生成的相同条目。

* 分词 Analysis

IKAnalyzer是一款开源的基于java语言开发的轻量级的中文分词工具包.


# 原理





























# 版本变化

## 打破5.4 编辑的变化

按查询删除API更改编辑
没有显式查询的请求将被弃用，并且在Elasticsearch 6.0.0中将无效。

默认设置不再被支持编辑
以前版本的Elasticsearch允许用户为任何设置设置默认设置。默认设置仅适用于实际设置尚未设置的情况。这个功能很糟糕，它引入的复杂性容易出错。由于这个原因，我们选择作出次要版本重大更改与外删除此功能default.path.conf， default.path.data和default.path.logs它仍然支持包装。Elasticsearch的未来版本也将删除对这些的支持，所以用户应该停止依赖这个功能。

检查索引是否存在编辑
带动/{index}词的端点HEAD可用于检查是否index存在索引匹配（index可以是逗号分隔的索引名称或索引模式列表）。这个动词的行为与GET在同一个端点上的行为有两种不同的方式。首先是发送相同的请求，GET并HEAD 可能在某些情况下返回不同的状态代码（例如，GET /pattern-that-has-no-matches*将200空的响应和HEAD /pattern-that-has-no-matches*将404空身（和 content-length头为零）。第二个是对此的任何HEAD请求端点将返回一个content-length零头，这两个都违反了HTTP规范：如果HEAD支持，HEAD请求必须返回相同的状态GET请求会，并且它必须返回一个content-length头相当于content-length头相同的GET请求会。这个行为已经被解决了，所以HEAD总是返回一样的状态码GET，和正确的一样 content-length。但是，这意味着HEAD /pattern-that-has-no-matches* 作为一个索引存在检查不再是404s，而是200s，就好像它是一个GET请求。要获得以前的行为，您必须添加参数 ?allow_no_indices=false（此参数默认为true）。

## 打破5.3 编辑的变化

包装更改编辑
记录配置编辑
以前，Elasticsearch公开了一个系统属性（es.logs），其中包括配置日志目录的绝对路径，以及用于各种日志文件（主日志文件，弃用日志和慢日志）的文件名的前缀。该属性已被替换为三个属性：

es.logs.base_path：配置日志目录的绝对路径
es.logs.cluster_name：用于各种日志文件的文件名的默认前缀
es.logs.node_name：如果node.name配置为包含在各种日志文件的文件名中（如果您愿意的话）
该属性es.logs已被弃用，并将在Elasticsearch 6.0.0中被删除。

使用Netty 3已被弃用编辑
Netty 3 for transport（transport.type=netty3）或HTTP（http.type=netty3）的使用已被弃用，并将在Elasticsearch 6.0.0中被删除。

设置更改编辑
Lenient布尔表示形式被弃用编辑
以外的值的使用false，"false"，true和"true"在布尔设置过时。

REST API更改编辑
Lenient布尔表示形式被弃用编辑
以外的值的使用false，"false"，true和"true"为布尔请求参数和在REST API调用主体布尔属性已被弃用。

映射更改编辑
Lenient布尔表示形式被弃用编辑
以外的值的使用false，"false"，true和"true"用于映射布尔值被弃用。

## 打破5.2 编辑的变化
包装更改编辑
系统调用引导检查编辑
Elasticsearch试图从版本2.1.0开始安装一个系统调用过滤器。在某些系统上，安装此系统调用过滤器可能会失败。以前的Elasticsearch版本会记录一个警告，但会继续执行，可能会让最终用户不知道这种情况。从Elasticsearch 5.2.0开始，现在有一个成功安装系统调用过滤器的 引导检查。如果由于此引导程序检查而遇到启动Elasticsearch的问题，则需要修复配置以便安装系统调用筛选器，否则可能需要自行承担禁用系统调用筛选器检查的风险。

设置更改编辑
系统调用过滤器设置编辑
Elasticsearch试图从版本2.1.0开始安装一个系统调用过滤器。这些是默认启用的，可以通过禁用bootstrap.seccomp。这个设置的命名很差，因为seccomp是Linux特有的，但是Elasticsearch试图在不同的操作系统上安装一个系统调用过滤器。从Elasticsearch 5.2.0开始，这个设置已经被重命名为bootstrap.system_call_filter。以前的设置仍然支持，但将在Elasticsearch 6.0.0中被删除。

Java API更改编辑
删除了一些source覆盖编辑
为了清理内部，我们删除了以下方法：

PutRepositoryRequest#source(XContentBuilder)
PutRepositoryRequest#source(String)
PutRepositoryRequest#source(byte[])
PutRepositoryRequest#source(byte[], int, int)
PutRepositoryRequest#source(BytesReference)
CreateSnapshotRequest#source(XContentBuilder)
CreateSnapshotRequest#source(String)
CreateSnapshotRequest#source(byte[])
CreateSnapshotRequest#source(byte[], int, int)
CreateSnapshotRequest#source(BytesReference)
RestoreSnapshotRequest#source(XContentBuilder)
RestoreSnapshotRequest#source(String)
RestoreSnapshotRequest#source(byte[])
RestoreSnapshotRequest#source(byte[], int, int)
RestoreSnapshotRequest#source(BytesReference)
RolloverRequest#source(BytesReference)
ShrinkRequest#source(BytesReference)
UpdateRequest#fromXContent(BytesReference)
请使用非source方法，而不是（如settings和type）。

摄取处理器的时间戳元数据字段类型已更改编辑
摄取处理器的“时间戳”元数据字段的类型已从更改java.lang.String为java.util.Date。


不推荐使用Shadow Replicas 编辑
阴影副本看不到太多的用法，我们正在计划删除它们。

## 打破5.1 编辑的变化

指数API更改编辑
别名是针对索引名称编辑的（大部分）规则进行验证的
别名现在用几乎相同的一组验证索引名称的规则进行验证。唯一的区别是允许别名使用大写字符。这意味着别名可能不会：

开始_，-或+
包括#，\，/，*，?，"，<，>，|，`, `,
长于100个UTF-8编码字节
正确.或..
5.1.0之前的版本中创建的别名仍然受支持，但不能添加违反这些规则的新别名。由于在elasticsearch中修改别名会将其删除并使用_aliasesAPI 以原子方式重新创建，因此不再支持使用无效名称修改别名。

Java API更改编辑
Log4j依赖项已经升级编辑
Log4j依赖已经从版本2.6.2升级到版本2.7。如果您在应用程序中使用传输客户端，则应相应地更新Log4j依赖项。

本地发现已被删除编辑
本地发现已被删除; 此发现实现在部落服务内部以及在同一个JVM内部运行多个节点的测试中使用。这意味着设置discovery.type为local启动失败。

插件API更改编辑
UnicastHostsProvider现在基于拉编辑
插入一个UnicastHostsProvider禅宗发现现在是基于拉。实现DiscoveryPlugin并覆盖该getZenHostsProviders方法。选择一个主机提供者现在也用一个单独的设置来完成discovery.zen.hosts_provider。

ZenPing和MasterElectService插件删除编辑
这些类不再可插入。要么实现自己的发现，要么从ZenDiscovery扩展并根据需要进行自定义。

onModule支持删除编辑
插件以前可以实现onModule一个Guice模块的名字的方法。所有onModule用于插入自定义行为的用法现在已被转换为基于pull的插件，并且onModule的挂钩已被删除。

其他API更改编辑
指标统计信息和节点统计信息API无法识别的指标编辑
索引统计信息和节点统计信息API允许查询各种指标的Elasticsearch。以前版本的Elasticsearch会默默接受无法识别的度量（例如，类似于“transprot”的拼写错误）。在5.1.0中，情况不再是这样; 无法识别的指标将导致请求失败。有一个例外是在5.0.0中删除的percolate指标，但是对于这些指标的请求只会在5.1.0版本的5.x系列中产生一个警告，并且会像6.0.0中的任何其他无法识别的指标一样发生警告。

## 打破5.0 编辑的变化
本节讨论将应用程序迁移到Elasticsearch 5.0时需要注意的更改。

迁移插件编辑
该elasticsearch-migration插件 （与Elasticsearch 2.3.0及以上版本兼容）将帮助您找到升级到Elasticsearch 5.0时需要解决的问题。

在5.0 编辑之前创建的索引
Elasticsearch 5.0可以读取在2.0或更高版本中创建的索引。Elasticsearch 5.0节点不会在Elasticsearch 2.0之前的版本中创建索引时启动。

重要
来自Elasticseach 1.x或之前的Reindex指数
在Elasticsearch 1.x或之前创建的索引需要用Elasticsearch 2.x或5.x重新索引，以便Elasticsearch 5.x可读。使用upgradeAPI 是不够的。请参阅Reindex以获取更多详细信息。

Elasticsearch 5.0首次启动时，它会自动重命名索引文件夹来使用索引UUID而不是索引名称。如果您正在使用 带有共享数据文件夹的影子副本，请首先启动一个可访问所有数据文件夹的节点，然后在启动群集中的其他节点之前重命名所有索引文件夹。


[2.x -> 5.0](https://www.elastic.co/guide/en/elasticsearch/reference/5.4/breaking-changes-5.0.html)



