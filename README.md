# Create bootstrap node

```
$ ./l2 docker genesis bootstrap
```

# Create a new node

```
$ ./l2 docker genesis node
```

# start a node

```
$ ./l2 docker start
```

# create beaconscan
    
``` 
$ ./scan docker build
```

# start beaconscan

```
$ ./scan docker start
```

# stop beaconscan

```
$ ./scan docker stop
```

# start etherscan
```
 $ ./l2 explorer start
```

# debug mode
```
$ ./prysm-debug.sh start beacon
$ ./prysm-debug.sh start validator
```

# need to fix for security
- get rid of `COPY geth_password.txt jwt.hex secret.txt /root/eth_bootstrap/` in Dockerfile