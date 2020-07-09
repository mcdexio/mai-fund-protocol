const Web3 = require('web3');
const { fromRpcSig } = require('ethereumjs-util');
const assert = require('assert');
const BigNumber = require('bignumber.js');
const { sha3, ecrecover, hashPersonalMessage, toBuffer, pubToAddress } = require('ethereumjs-util');
const { toWad, fromWad, infinity, Side } = require('./utils');

const getWeb3 = () => {
    const w = new Web3(web3.currentProvider);
    // const w = new Web3("http://server10.jy.mcarlo.com:8746");
    return w;
};

const sha3ToHex = message => {
    return '0x' + sha3(message).toString('hex');
};

const addLeadingZero = (str, length) => {
    let len = str.length;
    return '0'.repeat(length - len) + str;
};

const addTailingZero = (str, length) => {
    let len = str.length;
    if (len == length) {
        return str;
    }
    return str + '0'.repeat(length - len);
};

const isValidSignature = (account, signature, message) => {
    let pubkey;
    const v = parseInt(signature.config.slice(2, 4), 16);
    const method = parseInt(signature.config.slice(4, 6), 16);
    if (method === 0) {
        pubkey = ecrecover(
            hashPersonalMessage(toBuffer(message)),
            v,
            toBuffer(signature.r),
            toBuffer(signature.s)
        );
    } else if (method === 1) {
        pubkey = ecrecover(toBuffer(message), v, toBuffer(signature.r), toBuffer(signature.s));
    } else {
        throw new Error('wrong method');
    }

    const address = '0x' + pubToAddress(pubkey).toString('hex');
    return address.toLowerCase() == account.toLowerCase();
};


const calcRate = (rate) => {
    if (rate >= 0) {
        return new Number(rate).toString(16);
    }
    return (65536 - Math.abs(rate)).toString(16);
};

const generateOrderData = (
    version,
    isSell,
    isMarket,
    expiredAtSeconds,
    makerFeeRate,
    takerFeeRate,
    salt,
    isMakerOnly,
    isInversed,
    chainId
) => {
    let res = '0x';
    res += addLeadingZero(new BigNumber(version).toString(16), 2);
    res += isSell ? '01' : '00';
    res += isMarket ? '01' : '00';
    res += addLeadingZero(new BigNumber(expiredAtSeconds).toString(16), 5 * 2);
    res += addLeadingZero(calcRate(makerFeeRate), 2 * 2);
    res += addLeadingZero(calcRate(takerFeeRate), 2 * 2);
    res += addLeadingZero(new BigNumber(0).toString(16), 2 * 2);
    res += addLeadingZero(new BigNumber(salt).toString(16), 8 * 2);
    res += isMakerOnly ? '01' : '00';
    res += isInversed ? '01' : '00';
    res += addLeadingZero(new BigNumber(chainId).toString(16), 8 * 2);
    return addTailingZero(res, 66);
};

const EIP712_DOMAIN_TYPEHASH = sha3ToHex('EIP712Domain(string name)');
const EIP712_ORDER_TYPE = sha3ToHex(
    "Order(address trader,address broker,address perpetual,uint256 amount,uint256 price,bytes32 data)"
);

const getDomainSeparator = () => {
    return sha3ToHex(EIP712_DOMAIN_TYPEHASH + sha3ToHex('Mai Protocol').slice(2));
};

const getEIP712MessageHash = message => {
    return sha3ToHex('0x1901' + getDomainSeparator().slice(2) + message.slice(2), {
        encoding: 'hex'
    });
};

const getOrderHash = order => {
    return getEIP712MessageHash(
        sha3ToHex(
            EIP712_ORDER_TYPE +
            addLeadingZero(order.trader.slice(2), 64) +
            addLeadingZero(order.broker.slice(2), 64) +
            addLeadingZero(order.perpetual.slice(2), 64) +
            addLeadingZero(new BigNumber(order.amount).toString(16), 64) +
            addLeadingZero(new BigNumber(order.price).toString(16), 64) +
            order.data.slice(2)
        )
    );
};

const getOrderSignature = async (order, signer) => {
    const orderHash = getOrderHash(order);
    const newWeb3 = getWeb3();

    // This depends on the client, ganache-cli/testrpc auto prefix the message header to message
    // So we have to set the method ID to 0 even through we use web3.eth.sign
    signer = signer || order.trader;
    const signature = fromRpcSig(await newWeb3.eth.sign(orderHash, signer));
    signature.config = `0x${signature.v.toString(16)}00` + '0'.repeat(60);
    const isValid = isValidSignature(signer, signature, orderHash);

    assert.equal(true, isValid);
    order.signature = signature;
    order.orderHash = orderHash;
};

const getExpiredAt = orderParam => {
    const now = Date.parse(new Date()) / 1000;
    expiredAtSeconds = orderParam.expiredAtSeconds;
    expiredAt = orderParam.expiredAt;
    if (expiredAtSeconds !== undefined && expiredAtSeconds != 0) {
        return now + expiredAtSeconds;
    }
    if (expiredAt !== undefined) {
        return expiredAt;
    }
    return now + 86400;
};

const buildOrder = async (orderParam, perpetual, broker, signer) => {
    const order = {
        trader: orderParam.trader,
        broker: broker,
        perpetual: perpetual,
        amount: orderParam.amount,
        price: orderParam.price,
        data: generateOrderData(
            orderParam.version || 2,
            orderParam.side === 'sell',
            orderParam.type === 'market',
            getExpiredAt(orderParam),
            orderParam.makerFeeRate || 0,
            orderParam.takerFeeRate || 0,
            orderParam.salt || 10000000,
            orderParam.makerOnly || false,
            orderParam.inversed || false,
            orderParam.chainId || 1
        ),
    };
    await getOrderSignature(order, signer);
    return order;
};

const buildOrderEx = async (orderParam, perpetual, broker) => {
    const now = Date.parse(new Date()) / 1000;
    const order = {
        trader: orderParam.trader,
        broker: broker,
        perpetual: perpetual,
        amount: toWad(orderParam.amount),
        price: toWad(orderParam.price),
        data: generateOrderData(
            orderParam.version || 2,
            orderParam.side === 'sell',
            orderParam.type === 'market',
            orderParam.expiredAt,
            orderParam.makerFeeRate || 0,
            orderParam.takerFeeRate || 0,
            orderParam.salt || 10000000,
            orderParam.inversed || false,
            orderParam.chainId || 1
        ),
    };
    await getOrderSignature(order);
    return order;
};

module.exports = {
    getOrderHash,
    getOrderSignature,
    buildOrder,
    getDomainSeparator,
    EIP712_DOMAIN_TYPEHASH,
    getEIP712MessageHash

};
