
# What's this?

This is an application to run wasm on RuxOS using [WAMR](https://github.com/bytecodealliance/wasm-micro-runtime), which is a wasm runtime developed by Intel and currently belongs to the [Bytecode Alliance](https://github.com/bytecodealliance).

The `main.wasm` and other wasm files  in `rootfs/`is compiled from `.c` files using the WASM compiler. The `rootfs/` is a minimal rootfs for RuxOS in this application using 9pfs.

# How to build?

The compilation of `WAMR` depends on `cmake`.

To run your custom wasm application in RuxOS, you need to compile the wasm file first, or you can use the pre-compiled wasm file in the `rootfs/` as a demo.

We use `wasi-sdk` to compile the wasm file. You can download the `wasi-sdk` from [here](https://github.com/WebAssembly/wasi-sdk). Or you can use other wasm compiler.

In the path of your application file `main.c`, use the following command to compile the wasm file:

```bash
$WASI_SDK_DIR/bin/clang -O3 -o main.wasm main.c
```

Or you can put the `main.wasm` file from somewhere else into the rootfs.


# How to run?

After you have compiled the `.wasm` file, you can run it in ruxos.

- Run `HelloWorld`:

Run `HelloWorld` in ruxos using the following command:

```bash
make A=apps/c/wamr ARCH=aarch64 LOG=info SMP=4 run MUSL=y NET=y V9P=y V9P_PATH=apps/c/wamr/rootfs ARGS="iwasm,/main.wasm"
```

- Run the 2048 game:

Run the 2048 game in ruxos using the following command:

```bash
make A=apps/c/wamr ARCH=aarch64 LOG=info SMP=4 run MUSL=y NET=y V9P=y V9P_PATH=apps/c/wamr/rootfs ARGS="iwasm,/2048.wasm"
```

Input `w/a/s/d` to enjoy the game.

# WASI-NN

If you want to run WAMR with NN (Neural Network) support, you need to run `make` command with `WASI_NN=1`:

```bash
make A=apps/c/wamr ARCH=aarch64 LOG=info run MUSL=y NET=y V9P=y V9P_PATH=apps/c/wamr/rootfs ARGS="iwasm,--env="TARGET=cpu",--dir=.,/test_tensorflow.wasm" WASI_NN=1
```

If you want to compile the demo with NN support by yourself, you can run the following command in `apps/c/wamr/wasm-micro-runtime-{version}/core/iwasm/libraries/wasi-nn/test/` directory:

```bash
/opt/wasi-sdk/bin/clang \
    -Wl,--allow-undefined \
    -Wl,--strip-all,--no-entry \
    --sysroot=/opt/wasi-sdk/share/wasi-sysroot \
    -I../include -I../src/utils \
    -o test_tensorflow.wasm \
    test_tensorflow.c utils.c
```

And copy the `test_tensorflow.wasm` to the `apps/c/wamr/rootfs/` directory.

```bash
cp test_tensorflow.wasm ../../../../../../rootfs/
```

Then run the `make` command above to enjoy the NN support in ruxos.

# Further

You can also run other wasm files in ruxos using this application. Just compile the `.wasm` file and put it into the `rootfs/` directory. Then run it using the command above, only change the `ARGS` parameter, and you can enjoy the wasm application in ruxos.
