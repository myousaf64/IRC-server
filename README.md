# ircserv

An IRC server in C++ supporting multiple clients over a single non-blocking socket
loop, with channels, operator privileges and the standard command set. A 42 Abu Dhabi project.

Built with mahahahad and NuhaOsman.

## Build

```
make          # release build
make debug    # debug build
make asan     # AddressSanitizer build
```

## Run

```
./ircserv <port> <password>
```

## Test and analysis

```
make test        # test suite under tests/
make test-asan   # tests under AddressSanitizer
make valgrind    # memory check
make coverage    # coverage report
make check       # cppcheck and clang-tidy
```

`make help` lists every target.

## Notes

- The solo version lives in [dal-chawal](https://github.com/myousaf64/dal-chawal).
- This repository has open issues; see the issue tracker for current work.
