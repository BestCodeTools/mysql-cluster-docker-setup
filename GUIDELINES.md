# How to use the MySQL Cluster Images from DockerHUB

Guideline source: https://hub.docker.com/r/mysql/mysql-cluster


## Start a MySQL Cluster Using Default Configuration
Note that the ordering of container startup is very strict, and will likely need to be started from scratch if any step fails First we create an internal Docker network that the containers will use to communicate

```shell
docker network create cluster --subnet=192.168.0.0/16
```

Then we start the management node

```shell
docker run -d --net=cluster --name=management1 --ip=192.168.0.2 mysql/mysql-cluster ndb_mgmd
```

The two data nodes

```shell
docker run -d --net=cluster --name=ndb1 --ip=192.168.0.3 mysql/mysql-cluster ndbd
docker run -d --net=cluster --name=ndb2 --ip=192.168.0.4 mysql/mysql-cluster ndbd
```

And finally the MySQL server node

```shell
docker run -d --net=cluster --name=mysql1 --ip=192.168.0.10 -e MYSQL_RANDOM_ROOT_PASSWORD=true mysql/mysql-cluster mysqld
```

The server will be initialized with a randomized password that will need to be changed, so fetch it from the log, then log in and change the password. If you get an error saying «ERROR 2002 (HY000): Can't connect to local MySQL server through socket» then the server has not finished initializing yet.

```shell
docker logs mysql1 2>&1 | grep PASSWORD
docker exec -it mysql1 mysql -uroot -p
```

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPass';
```

Finally start a container with an interactive management client to verify that the cluster is up

```shell
docker run -it --net=cluster mysql/mysql-cluster ndb_mgm
```

Run the SHOW command to print cluster status. You should see the following

```shell
Starting ndb_mgm
-- NDB Cluster -- Management Client --
ndb_mgm> show
Connected to Management Server at: 192.168.0.2:1186
Cluster Configuration
---------------------
[ndbd(NDB)]	2 node(s)
id=2	@192.168.0.3  (mysql-5.7.18 ndb-7.6.2, Nodegroup: 0, *)
id=3	@192.168.0.4  (mysql-5.7.18 ndb-7.6.2, Nodegroup: 0)

[ndb_mgmd(MGM)]	1 node(s)
id=1	@192.168.0.2  (mysql-5.7.18 ndb-7.6.2)

[mysqld(API)]	1 node(s)
id=4	@192.168.0.10  (mysql-5.7.18 ndb-7.6.2)
```


## Customizing MySQL Cluster

The default MySQL Cluster image includes two config files which are also available in the github repository at https://github.com/mysql/mysql-docker/tree/mysql-cluster

* /etc/my.cnf
* /etc/mysql-cluster.cnf To change the cluster, for instance by adding more nodes or change the network setup, these files must be updated. For more information on how to do so, please refer to the MySQL Cluster documentation at to https://dev.mysql.com/doc/index-cluster.html To map up custom config files when starting the container, add the -v flag to load an external file. Example: docker run -d --net=cluster --name=management1 --ip=192.168.0.2 -v /mysql-cluster.cnf:/etc/mysql-cluster.cnf mysql/mysql-cluster ndb_mgmd


## Supported Docker Versions
These images are officially supported by the MySQL team on Docker version 1.9. Support for older versions (down to 1.0) is provided on a best-effort basis, but we strongly recommend running on the most recent version, since that is assumed for parts of the documentation above.

## User Feedback
We welcome your feedback! For general comments or discussion, please drop us a line in the Comments section below. For bugs and issues, please submit a bug report at http://bugs.mysql.com under the category "MySQL Package Repos and Docker Images".