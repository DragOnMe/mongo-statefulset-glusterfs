# MongoDB Deployment Demo for Kubernetes with dynamic glusterfs pv

* 별도 설정 변경이나 수작업 없이 스크립트로 MongoDB Replica Set 을 생성하고 정리할 수 있음
* MongoDB Replica Set을 Kubernetes Cluster 내에 StatefulSet 으로 구현함
* Bash script 내에서 kubectl 명령으로 Mongo Shell을 통해 Replica Set 설정을 수행하고 mongo admin 계정을 생성
* Replica Set 구성을 위한 별도의 sidecar 컨테이너를 쓰지 않음
* mongo image 버전: 아래 버전들에서 정상 작동 확인 완료
```
    mongo:3.4
    mongo:3.4.13
    mongo:3.6
    mongo:3.7

    * mongo:3.2 에서는 아래 컨테이너 실행 오류 발생함
    * "Error parsing option "wiredTigerCacheSizeGB" as int: Bad digit "." while parsing 0.25"
```

```
참고1: http://blog.kubernetes.io/2017/01/running-mongodb-on-kubernetes-with-statefulsets.html
참고2: https://github.com/pkdone/gke-mongodb-demo
```

## 1. How To Run

### 1.1 Prerequisites

Kubernetes 1.7~1.9x Cluster with glusterfs storage(HCI-like or external via HEKETI)

### 1.2 Main Deployment Steps 

1. 모든 sh 파일들은 a+x 로 실행 가능하도록 하고, MONGOD_STATEFULSET, MONGOD_NAMESPACE 변수를 원하는 값으로 설정.

* 각 스트립트 내에 Stateful Set 이름은 mongod-ss, 네임스페이스 이름은 ns-mongo 로 기본 값이 지정되어 있음.
* 서비스명(Headless Service)은 mongodb-hs로 YAML 내에 지정되어 있음.

```
    $ ./01-generate_mongo_ss.sh
```

3개의 mongod pod가 순차적으로 만들어지며(0>1>2), 마지막 pod까지 만들어지면 결과를 보여줌

각 mongod pod가 생성되는 동안 "Error from server (NotFound)", "error unable to upgrade connection" 등의 오류가 발생하지만 종료될 떄까지 무시

* 3 개의 mongod-ss-0,1,2 Pod가 Running 상태에 있더라도 Replication 초기화를 위한 대기상태에 도달하지 않았을 수 있다. 3개의 Pod 모두에서 log를 확인하여 다음과 같은 log 내용이 반복적으로 보일때까지 대기

```
    $ kubectl logs -f -n ns-mongo mongod-ss-0
    ...
    2018-04-18T05:45:59.950+0000 I REPL     [initandlisten] Did not find local Rollback ID document at startup. Creating one.
    2018-04-18T05:45:59.951+0000 I STORAGE  [initandlisten] createCollection: local.system.rollback.id with generated UUID: c5747cfc-2b8a-43e8-a4ad-45c7a00d5cb6
    2018-04-18T05:46:01.292+0000 I REPL     [initandlisten] Initialized the rollback ID to 1
    2018-04-18T05:46:01.292+0000 I REPL     [initandlisten] Did not find local replica set configuration document at startup;  NoMatchingDocument: Did not find replica set configuration document in local.system.replset
    2018-04-18T05:46:01.293+0000 I NETWORK  [initandlisten] waiting for connections on port 27017
    ...
    2018-04-18T05:51:01.292+0000 I CONTROL  [thread1] Sessions collection is not set up; waiting until next sessions refresh interval: Replication has not yet been configured
    2018-04-18T05:56:01.292+0000 I CONTROL  [thread2] Sessions collection is not set up; waiting until next sessions refresh interval: Replication has not yet been configured
    ...
```

2. 다음 스크립트를 실행하면, Mongo Shell 을 통해서 (1) MongoDB Replica Set 이 설정되며 (2) MongoDB main_admin 계정이 생성(실행 인자로 암호 문자열 입력)

```
    $ ./02-configure_repset_auth.sh abc123
```

Kubernetes Cluster 내의 모든 app tier 에서 각각의 MongoDB 서버로 다음의 주소들로 접속 가능:

```
    mongod-ss-0.mongodb-hs.ns-mongo.svc.cluster.local:27017
    mongod-ss-1.mongodb-hs.ns-mongo.svc.cluster.local:27017
    mongod-ss-2.mongodb-hs.ns-mongo.svc.cluster.local:27017
```

### 1.3 Example Tests To Run To Check Things Are Working

다음 사항들을 점검:

1. 컨테이너로 기동된 모든 Replica Set의 멤버 mongod 서버들간의 데이터 동기화.
2. MongoDB Service/StatefulSet이 삭제되어도 데이터가 유지되며(persistent volume), 동일한 Persistent Volume Claim을 사용하므로 삭제 후 재생성(03-delete_service.sh ... 04-recreate_service.sh)을 할 경우 이전의 데이터 및 Replica Set 은 그대로 유지.


#### 1.3.1 Replication Test

다음의 절차대로 데이터 복제 테스트:

```
    $ export MONGOD_NAMESPACE="ns-mongo"
    $ export MONGO_CLIENT=`kubectl get pods -n $MONGOD_NAMESPACE | grep mongo-client | awk '{print $1}'`
    $ kubectl exec -it -n $MONGOD_NAMESPACE $MONGO_CLIENT -- mongo mongodb://mongod-ss-0.mongodb-hs.ns-mongo.svc.cluster.local:27017
    MainRepSet:PRIMARY> db.getSiblingDB('admin').auth("main_admin", "abc123");
    MainRepSet:PRIMARY> use test;
    MainRepSet:PRIMARY> db.testcoll.insert({a:1});
    MainRepSet:PRIMARY> db.testcoll.insert({b:2});
    MainRepSet:PRIMARY> db.testcoll.find();
```


첫 번 째 컨테이너(“mongod-ss-0”)에서 빠져나온 후. 두 번 째 컨테이너(“mongod-ss-1”)로 접속, 앞서 insert 한 데이터가 조회되는지 확인:

```
    $ kubectl exec -it -n $MONGOD_NAMESPACE $MONGO_CLIENT -- mongo mongodb://mongod-ss-1.mongodb-hs.ns-mongo.svc.cluster.local:27017
    MainRepSet:SECONDARY> db.getSiblingDB('admin').auth("main_admin", "abc123");
    MainRepSet:SECONDARY> use test;
    MainRepSet:SECONDARY> db.setSlaveOk(1);
    MainRepSet:SECONDARY> db.testcoll.find();
```

세 번 째 컨테이너("mongod-ss-2") 에서도 동일한 방식으로 조회, 확인


#### 1.3.2 Redeployment Without Data Loss Test

Service 와 StatefulSet/Pods 를 삭제하고 동일한 구성(mongodb-service.yaml)으로 MongoDB Replica Set을 다시 생성:

```
    $ ./03-delete_service.sh
    $ ./04-recreate_service.sh
```


3개의 StatefulSet Pod가 기동된 후, mongod 컨테이너("mongod-ss-1")로 접속하여 데이터 보존 확인:

```
    $ kubectl exec -it -n $MONGOD_NAMESPACE $MONGO_CLIENT -- mongo mongodb://mongod-ss-1.mongodb-hs.ns-mongo.svc.cluster.local:27017
    MainRepSet:SECONDARY> db.getSiblingDB('admin').auth("main_admin", "abc123");
    MainRepSet:SECONDARY> use test;
    MainRepSet:SECONDARY> db.setSlaveOk(1);
    MainRepSet:SECONDARY> db.testcoll.find();
```


### 1.4 Undeploying & Cleaning Down the Kubernetes Environment

다음의 스크립트를 실행하면 MongoDB Replica Set을 구성하는 모든 요소들(namespace 포함)이 삭제 됨 

```
    $ ./99-teardown.sh
```
