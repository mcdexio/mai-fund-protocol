module.exports = {
    port: 8555,
    // norpc: true,
    skipFiles: [
        'interface',
        'test',
        'lib/LibTypes.sol',
        'lib/'
    ],
    copyPackages: [
        '@openzeppelin/contracts'
    ],
    client: require('ganache-cli'),
    providerOptions: {
        "hardfork": "istanbul",
        accounts: [
            {
                secretKey: "0xc013164ef5035ba72923016114696ef61c240b1764c8649108941cb3866587d3",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x1c2479ae1354c9d03a352ae009be9b7a6d10aa1a86596a7011d2f475b33afe55",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x134422b02f47325706bec54bf932f5d336f89ba73de28ede48cb0360634f4d0a",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0xcd5e4d777d0ab8b76f99864c24a5a6844c52c549fb3659443892d2e1599ed963",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x9f241edaa1ad650e9588c8627a18402fc1182c84866ab8c8cd04f138717cdf88",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x9471141f5f3ccde0c1d8b8437ad7fe8478be326f8cfd3bf2baac8f0108bdb0d2",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x2b7b7413c1df87d628e5e360a4ade5a954afd31afbd778f46d6dda7fcab557cd",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0xd9b1ef840eeaf658f51304dfe40ad84130e88192556a480a62bbf02cda417f0a",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x0d1b0c691760b4823fa9f6a0c574d320eca64657d851beb549958a8c582fd63e",
                balance: "0x52b7d2dcc80cd400000000"
            },
            {
                secretKey: "0x73882805265514f783e96b083628d1914efec8d8a609956ea4109ec7fb40d111",
                balance: "0x52b7d2dcc80cd400000000"
            }
        ]
    }
};
