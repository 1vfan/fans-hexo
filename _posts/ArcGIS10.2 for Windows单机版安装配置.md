---
title: ArcGIS10.2 for Windows�����氲װ����
date: 2017-08-12 17:13:45
tags:
#NAME?
categories: 
#NAME?
---

��¼Esri ArcGIS10.2ȫ����Windows2008 R2�е����氲װ����˵��

<!--more-->

# ��װ��׼��

����һ��ͳһ�ļ����� �磨D:\ArcGisSoftware\��

```bash
Desktop : ArcGIS_Desktop_102_134924.iso 
Server  : ArcGIS_Server_Ent_Windows_102_134934.iso
.net3.5 : dotNetFx35setup.exe
Desktop�ƽ��ļ� : ARCGIS.exe ��service.txt
Servers��Ȩ��� : arcgisproduct.ecp
```

# ��װDesktop���ƽ�ArcGIS

��ѹ ``ArcGIS_Desktop_102_134924.iso`` ���̶�·�� �磨D:\ArcGisSoftware\Desktop\����˫�� ``ESRI.exe``.

## �����ʷ�汾

``Run Utility`` ж����ʷ�汾.

## ��װLicenseManager

��װLicenseManager����ͣLicense Service.

```bash
ArcGIS for Desktop -->  ArcGIS License Manager --> Setup
Ĭ�ϰ�װ·��
finish successfully installed
��ʼ�˵� ArcGIS --> License Manager --> License Server Administrator
start/stop License Service --> Stop
```

��һ����װDesktop.

## ����.net framework 3.5

���Setup��װDesktopʱ�����ܻ���ʾ��װArcGIS��Ҫ���?.net framework 3.5 ��֧�֣�û����ʾ�������ò��裩.

```bash
����� --> ���� --> ���� --> ��ӹ��� --> ��װ.net framework 3.5
```

��һ����װDesktop.

## ��װDesktop

finish��װDesktop��ᵯ��һ�����棬�����Ȳ��ù�.

```bash
ArcGIS for Desktop --> Setup
Complete
�Զ��尲װ·�� �磨D:\ArcGIS\�������Զ�����һ��Desktop10.2�ĸ�Ŀ¼��
python��װ·��Ĭ��
Install֮ǰ��֮�����ѡ��Ĺ�ȥ��
finish successfully installed
```

��һ���ƽ�ArcGIS.

## �ƽ�ArcGIS

���ƣ�D:\ArcGisSoftware\����׼����  ``ARCGIS.exe ��service.txt`` �滻��C:\Program Files (x86)\ArcGIS\License10.2\bin\���е���Ӧ�ļ�.

�� ``service.txt`` ������ͷ�� ``SERVER xxx ANY 27000`` �� ``xxx`` �����滻�ɱ����������.

```bash
��ʼ�˵� --> ArcGIS --> Licenseanager --> License ServerAdministrator
����/ֹͣ��ɷ��� --> ���� --> ���¶�ȡ���

��ʼ�˵� --> ArcGIS --> ArcGIS Administrator
ѡ���Ʒ --> Advanced(ArcInfo)������
��ɹ����� --> localhost
```

�ƽ���ɺ󣬵�� ``������`` ���Կ��� ``����:����`` ���б�����ArcGIS�����ƽ�.

## ������

��װ�����п��ܳ�������Ľ��������

* �رշ���ǽ
* ��������License�������¶�ȡ���
* ���ʵ��û�취�����°�װLicense���ٴ��ƽ�

# ��װServer��Adaptor

��װArcGIS Server 10.2 ��ǰ����Ԥ���Ѿ���װ�� ArcGIS Desktop 10.2.

## ���ϵͳ

ArcGIS Server 10.2 ���밲װ���û���ΪAdministrator�˻��£�������Ҫ����winϵͳ�и��˻�.

```bash
��ʼ�˵� --> �Ҽ�cmd������ʾ�� --> �Թ���Ա�������
���룺net user administrator /active:yes
����ɹ����
```

��֤administrator�û����ڣ����������룬�����޷���װArcGIS Server 10.2.

```bash
����� --> ���� --> �����û����� --> �û�
Administrator ?�Ҽ���������
```

## ��װServer

"��ѹ ``ArcGIS_Server_Ent_Windows_102_134934.iso`` ���̶�·�� �磨D:\ArcGisSoftware\Server\����˫�� ``ESRI.exe`` , ``Run Utility`` ж����ʷ�汾."

```bash
ArcGIS for Server --> Setup
�Զ��尲װ·�� �磨D:\ArcGIS\Server\��
name: arcgis   password:�������������Ա����һ�ºü� ��GISadminpassword01��
python��װ·��Ĭ��
ѡ�� Do not export configure file
�����Ȩ��� arcgisproduct.ecp �����Ȩ
```

��Ȩ��ɺ����������ת��ArcGIS Server Managerҳ�棬ѡ�񴴽�һ����վ��.

```bash
������վ�����Ա���� (admin GIS123456)
�Զ��������Ŀ¼�洢·����D:\ArcGIS\arcgisserver\directories��
�Զ�����������ô洢·����D:\ArcGIS\arcgisserver\config-store��
```

��ɴ���վ�㣬��½ArcGIS Server������ http://localhost:6080/arcgis/manager/

## ��װAdaptor

```bash
ArcGIS for Server --> ArcGIS Web Adaptor(IIS) --> Setup
ѡ���Զ���װ����һ��
name of ArcGIS for Adaptor : arcgis
```

��װ�����ת��Web Adaptor����ҳ�棨http://localhost/arcgis/webadaptor/server��.

```bash
GIS ������ URL: http://localhost:6080
����Ա�û�����admin
���룺GIS123456

��ѡ��ͨ�� Web Adaptor ���ö�վ��Ĺ�����ʣ� �������
```

���óɹ�����ʾ��GIS��������ע�ᵽWeb Adaptor��.

��������� http://localhost/arcgis/rest/services �鿴�ѷ����ķ���ʹ��admin��½.
