# MongoDB Deployment Demo for Kubernetes with dynamic glusterfs pv

* 별도 설정 변경이나 수작업 없이 스크립트로 MongoDB Replica Set 을 생성하고 정리할 수 있음
* MongoDB Replica Set을 Kubernetes Cluster 내에 StatefulSet 으로 구현함
* Bash script 내에서 kubectl 명령으로 Mongo Shell을 통해 Replica Set 설정을 수행하고 mongo admin 계정을 생성
* Replica Set 구성을 위한 별도의 sidecar 컨테이너를 쓰지 않음

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
    $ export MONGO_CLIENT=`kubectl get pods | grep mongo-client | awk '{print $1}'`
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
    $ ./teardown.sh
```
