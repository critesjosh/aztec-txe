# aztec-txe
Command:
```
aztec test --show-output
```

# Reproducing:
```
Failed calling external resolver. RPC error response: RpcError { code: -32000, message: "DB has no contract with address 0x27ffa4fb3da8a80b6365315f9798c887474854c71c0720e1c5236861288ce147", data: None }
```

# Problem:
commenting Token transfer will fix it: 
https://github.com/ehsan-g/aztec-txe/blob/7a9eecf89f8cec4d9083109575914bc56eb2ee5a/contracts/myContract/src/main.nr#L63