# miniping

Minimum ping for my Zig study.

## How to build.

```
$ zig build
```

## How to run.

```
$ id -u
1000
$ cat /proc/sys/net/ipv4/ping_group_range
0       2147483647
$ id -g
1000
$ ./zig-out/bin/miniping 1.1.1.1
$ echo $?
0
$ ./zig-out/bin/miniping 224.0.0.1
error: Timeout
...
$
```

# License

[MIT](LICENSE)

# Author

[yskszk63](https://github.com/yskszk63)
